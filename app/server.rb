#!/usr/bin/env ruby
# frozen_string_literal: true

require 'rufus-scheduler'
require 'sinatra/base'

require_relative 'check_ssl_certs'

# Class that will handle metrics and health requests via Sinatra web server framework
class ScrapeServer < Sinatra::Base
  use Rack::Deflater

  configure do
    enable :logging
    set :server, 'thin'
    set :threaded, true
    set :port, ENV['LISTEN_PORT']
    set :logging, AppLogger.logger

    @scheduler = Rufus::Scheduler.new
    checker = SSLChecker.instance
    checker.configure(ENV['CHECK_HOSTS'])

    @scheduler.every (ENV['CHECK_INTERVAL'] || '3h') do
      checker.check
    end
    checker.check
  end

  configure :dev do
    AppLogger.logger.level = Logger::DEBUG
  end

  get '/healthz' do
    'ok'
  end

  get '/metrics' do
    SSLChecker.instance.export
  end

  not_found do
    '404 not found'
  end

  run! if app_file == $PROGRAM_NAME
end
