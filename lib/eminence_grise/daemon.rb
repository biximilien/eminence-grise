# frozen_string_literal: true

require "fileutils"

module EminenceGrise
  # Low-level pidfile-backed process daemon helper.
  #
  # Most users should prefer {ProcessRunner}, which configures the Ruby command
  # and framework log defaults.
  class Daemon
    attr_reader :command, :pidfile, :working_directory, :stdin, :stdout, :stderr

    # @param command [Array<String>, String] command to spawn
    # @param pidfile [String] pidfile path
    # @param working_directory [String]
    # @param stdin [String] stdin redirection path
    # @param stdout [String] stdout redirection path
    # @param stderr [String] stderr redirection path
    # @param spawner [#call, nil] injectable process spawner
    # @param detacher [#call, nil] injectable process detacher
    # @param signaler [#call, nil] injectable signal sender
    # @param process_checker [#call, nil] injectable process checker
    def initialize(
      command:,
      pidfile:,
      working_directory: Dir.pwd,
      stdin: File::NULL,
      stdout: File::NULL,
      stderr: stdout,
      spawner: nil,
      detacher: nil,
      signaler: nil,
      process_checker: nil
    )
      @command = Array(command)
      @pidfile = pidfile
      @working_directory = working_directory
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @spawner = spawner || Process.method(:spawn)
      @detacher = detacher || Process.method(:detach)
      @signaler = signaler || Process.method(:kill)
      @process_checker = process_checker || Process.method(:kill)
    end

    # Spawn and detach the configured process.
    #
    # @return [Integer] child process id
    # @raise [ArgumentError] when command is empty
    def start
      raise ArgumentError, "daemon command cannot be empty" if @command.empty?
      raise "process already running with pid #{pid}" if running?

      prepare_files

      child_pid = @spawner.call(*@command, chdir: @working_directory, in: @stdin, out: @stdout, err: @stderr)
      @detacher.call(child_pid)
      File.write(@pidfile, child_pid.to_s)
      child_pid
    end

    # Stop the daemon process named in the pidfile.
    #
    # @param signal [String]
    # @return [Boolean] true when a live process was signaled
    def stop(signal: "TERM")
      current_pid = pid
      unless current_pid
        FileUtils.rm_f(@pidfile)
        return false
      end

      unless process_alive?(current_pid)
        FileUtils.rm_f(@pidfile)
        return false
      end

      @signaler.call(signal, current_pid)
      FileUtils.rm_f(@pidfile)
      true
    end

    # @return [Boolean]
    def running?
      current_pid = pid
      current_pid && process_alive?(current_pid)
    end

    # @return [Integer, nil]
    def pid
      return nil unless File.exist?(@pidfile)

      Integer(File.read(@pidfile).strip)
    rescue ArgumentError
      nil
    end

    private

    def prepare_files
      FileUtils.mkdir_p(File.dirname(@pidfile))
      [@stdin, @stdout, @stderr].uniq.each do |path|
        next if path == File::NULL

        FileUtils.mkdir_p(File.dirname(path))
      end
    end

    def process_alive?(current_pid)
      @process_checker.call(0, current_pid)
      true
    rescue Errno::ESRCH
      false
    rescue Errno::EPERM
      true
    end
  end
end
