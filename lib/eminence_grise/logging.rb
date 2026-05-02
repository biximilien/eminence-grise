# frozen_string_literal: true

require "fileutils"
require "json"
require "logger"
require "time"

module EminenceGrise
  module Logging
    module_function

    def console(level: Logger::INFO, format: :text, io: $stdout)
      build(io, level: level, format: format)
    end

    def file(path = ".eminence-grise/runner.log", level: Logger::INFO, format: :text)
      FileUtils.mkdir_p(File.dirname(path))
      io = File.open(path, "a")
      io.sync = true
      build(io, level: level, format: format)
    end

    def null
      build(File::NULL, level: Logger::FATAL, format: :text)
    end

    def coerce(logger)
      return null unless logger
      return logger if logger.respond_to?(:info) && logger.respond_to?(:warn) && logger.respond_to?(:error)

      PutsAdapter.new(logger) if logger.respond_to?(:puts)
    end

    def level(value)
      return value if value.is_a?(Integer)

      Logger.const_get(value.to_s.upcase)
    rescue NameError
      raise ArgumentError, "unknown log level: #{value.inspect}"
    end

    def build(output, level:, format:)
      logger = Logger.new(output)
      logger.level = level(level)
      logger.formatter = formatter(format)
      logger
    end

    def formatter(format)
      case format.to_sym
      when :text
        proc do |severity, time, _progname, message|
          "#{time.iso8601} #{severity.ljust(5)} #{message}\n"
        end
      when :json
        proc do |severity, time, _progname, message|
          JSON.generate(timestamp: time.iso8601, level: severity.downcase, message: message.to_s) + "\n"
        end
      else
        raise ArgumentError, "unknown log format: #{format.inspect}"
      end
    end

    class PutsAdapter
      def initialize(target)
        @target = target
      end

      def info(message)
        @target.puts(message)
      end

      def warn(message)
        @target.puts(message)
      end

      def error(message)
        @target.puts(message)
      end
    end
  end
end
