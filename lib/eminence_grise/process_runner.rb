# frozen_string_literal: true

require "rbconfig"

require_relative "daemon"
require_relative "logging"

module EminenceGrise
  class ProcessRunner
    DEFAULT_PIDFILE = ".eminence-grise/runner.pid"
    DEFAULT_LOG = ".eminence-grise/runner.log"
    DEFAULT_STDOUT = ".eminence-grise/runner.out.log"
    DEFAULT_STDERR = ".eminence-grise/runner.err.log"

    attr_reader :script, :pidfile, :log_path, :stdout, :stderr, :working_directory

    def initialize(
      script:,
      ruby: RbConfig.ruby,
      require_path: :auto,
      pidfile: DEFAULT_PIDFILE,
      log_path: DEFAULT_LOG,
      log_format: :text,
      log_level: Logger::INFO,
      logger: nil,
      stdout: DEFAULT_STDOUT,
      stderr: DEFAULT_STDERR,
      working_directory: Dir.pwd,
      daemon_class: Daemon,
      loader: nil
    )
      @script = script
      @ruby = ruby
      @pidfile = pidfile
      @log_path = log_path
      @log_format = log_format
      @log_level = log_level
      @logger = logger
      @stdout = stdout
      @stderr = stderr
      @working_directory = working_directory
      @require_path = resolve_require_path(require_path)
      @daemon_class = daemon_class
      @loader = loader || method(:load_script)
      @owned_loggers = []
    end

    def run_foreground
      require_script!

      with_working_directory do
        with_require_path do
          foreground_logger.info("foreground run started script=#{@script}")
          @loader.call(@script)
          foreground_logger.info("foreground run finished script=#{@script}")
        rescue StandardError => error
          foreground_logger.error("foreground run failed script=#{@script} error=#{error.message.inspect}")
          raise
        end
      end
    end

    def start_daemon
      require_script!

      daemon_logger.info("daemon start requested script=#{@script} log=#{@log_path}")
      pid = daemon.start
      daemon_logger.info("daemon started script=#{@script} pid=#{pid}")
      pid
    end

    def stop_daemon
      daemon.stop
    end

    def daemon_running?
      daemon.running?
    end

    def daemon_pid
      daemon.pid
    end

    def close
      @owned_loggers.each do |logger|
        logger.close if logger.respond_to?(:close)
      end
      @owned_loggers.clear
    end

    def daemon
      @daemon ||= @daemon_class.new(
        command: command,
        pidfile: @pidfile,
        stdout: @stdout,
        stderr: @stderr,
        working_directory: @working_directory
      )
    end

    private

    def command
      [@ruby].tap do |args|
        args.push("-I", @require_path) if @require_path
        args << @script if @script
      end
    end

    def with_working_directory(&block)
      Dir.chdir(@working_directory, &block)
    end

    def with_require_path
      original_load_path = $LOAD_PATH.dup
      $LOAD_PATH.unshift(@require_path) if @require_path && !$LOAD_PATH.include?(@require_path)
      yield
    ensure
      $LOAD_PATH.replace(original_load_path)
    end

    def load_script(script)
      load script
    end

    def foreground_logger
      @foreground_logger ||= @logger ? Logging.coerce(@logger) : own_logger(Logging.console(level: @log_level, format: @log_format))
    end

    def daemon_logger
      @daemon_logger ||= @logger ? Logging.coerce(@logger) : own_logger(Logging.file(@log_path, level: @log_level, format: @log_format))
    end

    def own_logger(logger)
      @owned_loggers << logger
      logger
    end

    def require_script!
      raise ArgumentError, "script is required" unless @script
    end

    def default_require_path
      File.directory?(File.join(@working_directory, "lib")) ? "./lib" : nil
    end

    def resolve_require_path(require_path)
      return default_require_path if require_path == :auto

      require_path
    end
  end
end
