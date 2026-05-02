# frozen_string_literal: true

require "fileutils"

module EminenceGrise
  class Daemon
    attr_reader :command, :pidfile, :working_directory, :stdin, :stdout, :stderr

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

    def start
      raise ArgumentError, "daemon command cannot be empty" if @command.empty?
      raise "process already running with pid #{pid}" if running?

      prepare_files

      child_pid = @spawner.call(*@command, chdir: @working_directory, in: @stdin, out: @stdout, err: @stderr)
      @detacher.call(child_pid)
      File.write(@pidfile, child_pid.to_s)
      child_pid
    end

    def stop(signal: "TERM")
      current_pid = pid
      return false unless current_pid
      unless process_alive?(current_pid)
        FileUtils.rm_f(@pidfile)
        return false
      end

      @signaler.call(signal, current_pid)
      FileUtils.rm_f(@pidfile)
      true
    end

    def running?
      current_pid = pid
      current_pid && process_alive?(current_pid)
    end

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
