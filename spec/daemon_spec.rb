# frozen_string_literal: true

require "tmpdir"

RSpec.describe EminenceGrise::Daemon do
  it "starts a detached process and writes a pidfile" do
    Dir.mktmpdir do |dir|
      calls = []
      spawner = lambda do |*args|
        calls << [:spawn, args]
        123
      end
      detacher = ->(pid) { calls << [:detach, pid] }
      process_checker = lambda do |_signal, _pid|
        raise Errno::ESRCH
      end

      daemon = described_class.new(
        command: ["ruby", "worker.rb"],
        pidfile: File.join(dir, "run", "worker.pid"),
        stdout: File.join(dir, "logs", "worker.out.log"),
        stderr: File.join(dir, "logs", "worker.err.log"),
        working_directory: dir,
        spawner: spawner,
        detacher: detacher,
        process_checker: process_checker
      )

      expect(daemon.start).to eq(123)
      expect(File.read(File.join(dir, "run", "worker.pid"))).to eq("123")
      expect(calls).to eq([
        [
          :spawn,
          [
            "ruby",
            "worker.rb",
            {
              chdir: dir,
              in: File::NULL,
              out: File.join(dir, "logs", "worker.out.log"),
              err: File.join(dir, "logs", "worker.err.log")
            }
          ]
        ],
        [:detach, 123]
      ])
    end
  end

  it "passes custom stdin to the spawned process" do
    Dir.mktmpdir do |dir|
      calls = []
      spawner = lambda do |*args|
        calls << args
        123
      end
      process_checker = lambda do |_signal, _pid|
        raise Errno::ESRCH
      end
      stdin = File.join(dir, "input.log")

      daemon = described_class.new(
        command: ["ruby", "worker.rb"],
        pidfile: File.join(dir, "worker.pid"),
        stdin: stdin,
        spawner: spawner,
        detacher: ->(_pid) {},
        process_checker: process_checker
      )

      daemon.start

      expect(calls.first.last).to include(in: stdin)
    end
  end

  it "does not start a second process when the pidfile is still running" do
    Dir.mktmpdir do |dir|
      pidfile = File.join(dir, "runner.pid")
      File.write(pidfile, "456")
      process_checker = ->(_signal, _pid) { true }

      daemon = described_class.new(
        command: ["ruby", "worker.rb"],
        pidfile: pidfile,
        process_checker: process_checker
      )

      expect { daemon.start }.to raise_error(RuntimeError, /already running/)
    end
  end

  it "stops a process from the pidfile" do
    Dir.mktmpdir do |dir|
      pidfile = File.join(dir, "runner.pid")
      File.write(pidfile, "789")
      signals = []
      signaler = ->(signal, pid) { signals << [signal, pid] }
      process_checker = ->(_signal, _pid) { true }

      daemon = described_class.new(
        command: ["ruby", "worker.rb"],
        pidfile: pidfile,
        signaler: signaler,
        process_checker: process_checker
      )

      expect(daemon.stop).to be(true)
      expect(signals).to eq([["TERM", 789]])
      expect(File).not_to exist(pidfile)
    end
  end

  it "removes a stale pidfile without signaling" do
    Dir.mktmpdir do |dir|
      pidfile = File.join(dir, "runner.pid")
      File.write(pidfile, "789")
      signals = []
      signaler = ->(signal, pid) { signals << [signal, pid] }
      process_checker = lambda do |_signal, _pid|
        raise Errno::ESRCH
      end

      daemon = described_class.new(
        command: ["ruby", "worker.rb"],
        pidfile: pidfile,
        signaler: signaler,
        process_checker: process_checker
      )

      expect(daemon.stop).to be(false)
      expect(signals).to be_empty
      expect(File).not_to exist(pidfile)
    end
  end
end
