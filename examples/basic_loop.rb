# frozen_string_literal: true

require "fileutils"

require "eminence_grise"

sandbox_directory = File.expand_path("../../eminence-grise-sandbox", __dir__)
output_path = File.join(sandbox_directory, ".eminence-grise/codex-last-message.txt")
FileUtils.mkdir_p(File.dirname(output_path))

queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(
    id: "sandbox-readme",
    title: "Improve the sandbox README",
    description: <<~TEXT,
      Use the sandbox repository as the target workspace:
      #{sandbox_directory}

      The sandbox can be modified unconditionally. Create or use the branch
      from task metadata, then update the README so it clearly explains that
      this repository is the disposable target for Eminence Grise agent tasks.

      Do not modify the Eminence Grise gem or demo app repositories.
    TEXT
    metadata: {
      working_directory: sandbox_directory,
      branch: "biximilien/docs/sandbox-readme"
    }
  )
])

agent = EminenceGrise::Agent.new do |task|
  codex = EminenceGrise::CodexAgent.new(
    working_directory: task.metadata_value(:working_directory),
    sandbox: "workspace-write",
    approval_policy: "never",
    output_last_message: output_path
  )

  FileUtils.rm_f(output_path)
  result = codex.call(task)
  message = File.exist?(output_path) ? File.read(output_path) : result.stdout
  puts message unless message.empty?
  warn "codex elapsed_seconds=#{format('%.2f', result.elapsed_seconds)}"
  warn "codex usage=#{result.usage.inspect}" unless result.usage.empty?
  result
end

runner = EminenceGrise::Runner.new(
  queue: queue,
  agent: agent,
  logger: EminenceGrise::Logging.console,
  wait_on_retry_at: false
)

begin
  runner.run
rescue EminenceGrise::CliAgent::ExecutionError => error
  warn error.message
  warn "codex elapsed_seconds=#{format('%.2f', error.result.elapsed_seconds)}" if error.result.elapsed_seconds
  warn "codex usage=#{error.result.usage.inspect}" unless error.result.usage.empty?
  exit 1
end
