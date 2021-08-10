# frozen_string_literal: true

require 'logger'

# Class responsible for all log handling within the app
class AppLogger
  extend SingleForwardable

  def_delegators :logger, :info, :error, :warn, :level

  class << self
    def logger
      return @_logger if @_logger

      @_logger = Logger.new $stdout
      @_logger.level = Logger::INFO
    end

    def suppress_logging
      @_logger.level = Logger::FATAL
    end
  end
end
