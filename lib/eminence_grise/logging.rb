# frozen_string_literal: true

require "fileutils"
require "json"
require "logger"
require "time"

module EminenceGrise
  # Factory methods for framework loggers.
  module Logging
    module_function

    # Build a console logger.
    #
    # @param level [Integer, String, Symbol]
    # @param format [:text, :json]
    # @param io [IO]
    # @return [Logger]
    def console(level: Logger::INFO, format: :text, io: $stdout)
      build(io, level: level, format: format)
    end

    # Build a file logger and create parent directories.
    #
    # @param path [String]
    # @param level [Integer, String, Symbol]
    # @param format [:text, :json]
    # @return [Logger]
    def file(path = ".eminence-grise/runner.log", level: Logger::INFO, format: :text)
      FileUtils.mkdir_p(File.dirname(path))
      io = File.open(path, "a")
      io.sync = true
      build(io, level: level, format: format)
    end

    # Build a logger that discards messages.
    #
    # @return [Logger]
    def null
      build(File::NULL, level: Logger::FATAL, format: :text)
    end

    # Convert nil, stdlib-compatible loggers, or puts-only objects to loggers.
    #
    # @param logger [Logger, #puts, nil]
    # @return [Logger, PutsAdapter]
    def coerce(logger)
      return null unless logger
      return logger if logger.respond_to?(:info) && logger.respond_to?(:warn) && logger.respond_to?(:error)

      PutsAdapter.new(logger) if logger.respond_to?(:puts)
    end

    # Convert a log level name to a Logger level.
    #
    # @param value [Integer, String, Symbol]
    # @return [Integer]
    # @raise [ArgumentError] when the level is unknown
    def level(value)
      return value if value.is_a?(Integer)

      Logger.const_get(value.to_s.upcase)
    rescue NameError
      raise ArgumentError, "unknown log level: #{value.inspect}"
    end

    # Build a Logger with the configured formatter.
    #
    # @api private
    def build(output, level:, format:)
      logger = Logger.new(output)
      logger.level = level(level)
      logger.formatter = formatter(format)
      logger
    end

    # Build a formatter proc for the requested format.
    #
    # @api private
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

    # Adapts puts-only objects to the logger interface used by the framework.
    #
    # @api private
    class PutsAdapter
      def initialize(target)
        @target = target
      end

      # Write an info message.
      def info(message)
        @target.puts(message)
      end

      # Write a warning message.
      def warn(message)
        @target.puts(message)
      end

      # Write an error message.
      def error(message)
        @target.puts(message)
      end
    end
  end
end
