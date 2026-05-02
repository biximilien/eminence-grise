# frozen_string_literal: true

require "rbconfig"

require_relative "daemon"

module EminenceGrise
  class ProcessRunner
    DEFAULT_PIDFILE = ".eminence-grise/runner.pid"
    DEFAULT_STDOUT = ".eminence-grise/runner.out.log"
    DEFAULT_STDERR = ".eminence-grise/runner.err.log"

    attr_reader :script, :pidfile, :stdout, :stderr, :working_directory

    def initialize(
      script:,
      ruby: RbConfig.ruby,
      require_path: default_require_path,
      pidfile: DEFAULT_PIDFILE,
      stdout: DEFAULT_STDOUT,
      stderr: DEFAULT_STDERR,
      working_directory: Dir.pwd,
      daemon_class: Daemon,
      loader: nil
    )
      @script = script
      @ruby = ruby
      @require_path = require_path
      @pidfile = pidfile
      @stdout = stdout
      @stderr = stderr
      @working_directory = working_directory
      @daemon_class = daemon_class
      @loader = loader || method(:load_script)
    end

    def run_foreground
      require_script!

      with_working_directory do
        add_require_path
        @loader.call(@script)
      end
    end

    def start_daemon
      require_script!

      daemon.start
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
        args << @script
      end
    end

    def add_require_path
      return unless @require_path

      $LOAD_PATH.unshift(@require_path) unless $LOAD_PATH.include?(@require_path)
    end

    def with_working_directory(&block)
      Dir.chdir(@working_directory, &block)
    end

    def load_script(script)
      load script
    end

    def require_script!
      raise ArgumentError, "script is required" unless @script
    end

    def default_require_path
      File.directory?("lib") ? "./lib" : nil
    end
  end
end
