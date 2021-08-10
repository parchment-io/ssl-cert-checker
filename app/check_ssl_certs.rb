#!/usr/bin/env ruby
# frozen_string_literal: true

require 'openssl'
require 'prometheus/client'
require 'prometheus/client/formats/text'
require 'singleton'
require 'socket'

require_relative 'logger'

# Class that performs SSL connect cert checks on demand and exports them to Prometheus text format
class SSLChecker
  include Singleton

  attr_reader :hosts, :results

  def configure(hosts)
    @hosts = hosts&.tr(' ', '')&.split(',')
    raise ArgumentError, 'no hosts to check have been configured' if @hosts.nil? || @hosts.empty?

    AppLogger.info("Configured to check hosts: #{@hosts.join(', ')}")

    @prometheus = Prometheus::Client.registry
    define_metrics
    register_metrics
  end

  def define_metrics
    labels = %i[connect_host subject issuer]
    @prom_checked = Prometheus::Client::Gauge.new(:ssl_cert_checked_time,
                                                  labels: labels,
                                                  docstring: 'Timestamp of when the cert was checked')
    @prom_expiry = Prometheus::Client::Gauge.new(:ssl_cert_expiry_time,
                                                 labels: labels,
                                                 docstring: 'Timestamp of when the cert will expire')
    @prom_issuer_expiry = Prometheus::Client::Gauge.new(:ssl_cert_issuer_expiry_time,
                                                        labels: labels,
                                                        docstring: 'Timestamp of when the cert\'s issuer will expire')
    @prom_success = Prometheus::Client::Gauge.new(:ssl_cert_check_success,
                                                  labels: %i[connect_host exception_message exception_class],
                                                  docstring: 'Labels with the result of the cert check')
  end

  def register_metrics
    @prometheus.register(@prom_checked)
    @prometheus.register(@prom_expiry)
    @prometheus.register(@prom_issuer_expiry)
    @prometheus.register(@prom_success)
  end

  def export
    Prometheus::Client::Formats::Text.marshal(@prometheus)
  end

  def check
    AppLogger.info('Checking configured hosts')
    hosts.each do |entry|
      host, port = entry.split(':')
      port ||= 443

      AppLogger.info("Connecting to #{entry}")
      begin
        ssl_client = ssl_connect(host, port)
        ssl_client.close
      rescue StandardError => e
        @prom_success.set(0, labels: { connect_host: entry, exception_class: e.class, exception_message: e.to_s })
        AppLogger.info("[#{entry}] unable to connect: #{e.class} #{e}")
        next
      end

      host_cert = ssl_client.peer_cert_chain[0]
      host_cert_issuer = ssl_client.peer_cert_chain[1]
      AppLogger.info("[#{entry}] #{host_cert.subject} expiry #{host_cert.not_after}, issuer #{host_cert.issuer} " \
                     "expiry #{host_cert_issuer&.not_after || 'unknown, not in chain'}")

      prom_labels = {
        connect_host: entry,
        subject: host_cert.subject.to_s,
        issuer: host_cert.issuer.to_s,
      }

      @prom_checked.set(Time.now.to_i, labels: prom_labels)
      @prom_expiry.set(host_cert.not_after.to_i, labels: prom_labels)
      @prom_issuer_expiry.set(host_cert_issuer&.not_after&.to_i || 0, labels: prom_labels)
      @prom_success.set(1, labels: { connect_host: entry, exception_class: '', exception_message: '' })
    end
    AppLogger.info('Done checking configured hosts')
  end

  private

  def ssl_connect(host, port)
    ssl_client = OpenSSL::SSL::SSLSocket.new(Socket.tcp(host, port.to_i, connect_timeout: 10, resolv_timeout: 10))
    ssl_client.hostname = host
    ssl_client.sync_close = true
    ssl_client.connect
    ssl_client
  end
end
