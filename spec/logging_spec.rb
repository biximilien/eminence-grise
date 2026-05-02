# frozen_string_literal: true

require "json"
require "stringio"
require "tmpdir"

RSpec.describe EminenceGrise::Logging do
  it "builds a console logger" do
    io = StringIO.new
    logger = described_class.console(io: io)

    logger.info("hello")

    expect(io.string).to include("INFO")
    expect(io.string).to include("hello")
  end

  it "builds a file logger and creates parent directories" do
    Dir.mktmpdir do |dir|
      path = File.join(dir, "logs", "runner.log")
      logger = described_class.file(path)

      logger.info("written")
      logger.close

      expect(File.read(path)).to include("written")
    end
  end

  it "supports JSON log lines" do
    io = StringIO.new
    logger = described_class.console(io: io, format: :json)

    logger.warn("careful")

    event = JSON.parse(io.string)
    expect(event).to include("level" => "warn", "message" => "careful")
    expect(event).to have_key("timestamp")
  end

  it "builds a null logger" do
    logger = described_class.null

    expect { logger.info("quiet") }.not_to raise_error
  end
end
