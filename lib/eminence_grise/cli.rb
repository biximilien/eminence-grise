# frozen_string_literal: true

require "optparse"
require "rbconfig"

require_relative "daemon"

module EminenceGrise
  class CLI
    DEFAULT_PIDFILE = ".eminence-grise/runner.pid"
    DEFAULT_STDOUT = ".eminence-grise/runner.out.log"
    DEFAULT_STDERR = ".eminence-grise/runner.err.log"

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
        ruby: RbConfig.ruby,
        require_path: default_require_path
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
        start_background(script, options)
      else
        $LOAD_PATH.unshift(options[:require_path]) if options[:require_path]
        load File.expand_path(script)
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

      daemon = Daemon.new(command: ["ruby"], pidfile: options[:pidfile])
      had_pidfile = File.exist?(options[:pidfile])
      if daemon.stop
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

      daemon = Daemon.new(command: ["ruby"], pidfile: options[:pidfile])
      if daemon.running?
        @stdout.puts "running pid #{daemon.pid}"
        0
      else
        @stdout.puts "not running"
        1
      end
    end

    def start_background(script, options)
      command = [options[:ruby]]
      command.push("-I", options[:require_path]) if options[:require_path]
      command << script

      daemon = Daemon.new(
        command: command,
        pidfile: options[:pidfile],
        stdout: options[:stdout],
        stderr: options[:stderr],
        working_directory: Dir.pwd
      )
      pid = daemon.start
      @stdout.puts "started pid #{pid}"
      0
    end

    def default_require_path
      File.directory?("lib") ? "./lib" : nil
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
