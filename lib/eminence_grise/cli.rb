# frozen_string_literal: true

require "optparse"

require_relative "process_runner"

module EminenceGrise
  class CLI
    DEFAULT_PIDFILE = ProcessRunner::DEFAULT_PIDFILE
    DEFAULT_STDOUT = ProcessRunner::DEFAULT_STDOUT
    DEFAULT_STDERR = ProcessRunner::DEFAULT_STDERR

    def initialize(argv, stdout: $stdout, stderr: $stderr)
      @argv = argv
      @stdout = stdout
      @stderr = stderr
    end

    def call
      command = @argv.shift

      case command
      when "run"
        run
      when "stop"
        stop
      when "status"
        status
      else
        @stderr.puts usage
        1
      end
    end

    private

    def run
      options = {
        background: false,
        pidfile: DEFAULT_PIDFILE,
        stdout: DEFAULT_STDOUT,
        stderr: DEFAULT_STDERR,
        ruby: nil,
        require_path: nil
      }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: eminence-grise run SCRIPT [options]"
        opts.on("--background", "Run SCRIPT as a detached background process") { options[:background] = true }
        opts.on("--pidfile PATH", "Write the background process pid to PATH") { |value| options[:pidfile] = value }
        opts.on("--stdout PATH", "Redirect background stdout to PATH") { |value| options[:stdout] = value }
        opts.on("--stderr PATH", "Redirect background stderr to PATH") { |value| options[:stderr] = value }
        opts.on("--ruby PATH", "Ruby executable to use for background runs") { |value| options[:ruby] = value }
        opts.on("-I", "--require-path PATH", "Add PATH to the Ruby load path") { |value| options[:require_path] = value }
      end
      parser.parse!(@argv)

      script = @argv.shift
      return fail_with(parser.to_s) unless script

      if options[:background]
        pid = process_runner(script, options).start_daemon
        @stdout.puts "started pid #{pid}"
        0
      else
        process_runner(script, options).run_foreground
        0
      end
    end

    def stop
      options = { pidfile: DEFAULT_PIDFILE }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: eminence-grise stop [options]"
        opts.on("--pidfile PATH", "Read the background process pid from PATH") { |value| options[:pidfile] = value }
      end
      parser.parse!(@argv)

      runner = process_runner(nil, options)
      had_pidfile = File.exist?(options[:pidfile])
      if runner.stop_daemon
        @stdout.puts "stopped #{options[:pidfile]}"
        0
      elsif had_pidfile
        @stdout.puts "not running; removed stale pidfile #{options[:pidfile]}"
        1
      else
        @stderr.puts "no pidfile found at #{options[:pidfile]}"
        1
      end
    end

    def status
      options = { pidfile: DEFAULT_PIDFILE }
      parser = OptionParser.new do |opts|
        opts.banner = "Usage: eminence-grise status [options]"
        opts.on("--pidfile PATH", "Read the background process pid from PATH") { |value| options[:pidfile] = value }
      end
      parser.parse!(@argv)

      runner = process_runner(nil, options)
      if runner.daemon_running?
        @stdout.puts "running pid #{runner.daemon_pid}"
        0
      else
        @stdout.puts "not running"
        1
      end
    end

    def process_runner(script, options)
      kwargs = {
        script: script,
        pidfile: options.fetch(:pidfile, DEFAULT_PIDFILE),
        stdout: options.fetch(:stdout, DEFAULT_STDOUT),
        stderr: options.fetch(:stderr, DEFAULT_STDERR)
      }
      kwargs[:ruby] = options[:ruby] if options[:ruby]
      kwargs[:require_path] = options[:require_path] if options[:require_path]
      ProcessRunner.new(**kwargs)
    end

    def fail_with(message)
      @stderr.puts message
      1
    end

    def usage
      <<~TEXT
        Usage:
          eminence-grise run SCRIPT [--background]
          eminence-grise stop [--pidfile PATH]
          eminence-grise status [--pidfile PATH]
      TEXT
    end
  end
end
