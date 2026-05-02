# Éminence Grise

Éminence Grise is an agentic development framework built in Ruby.

It uses a simple architecture and agent loop to allow developers to create agents that can perform coding tasks.

## Vision

Éminence Grise aims to be simple, but powerful.

The framework should require little to no configuration. It provides small Ruby building blocks for queues, runners, agents, orchestration, and process management, then expects external tools to bring their own configuration. For example, `CodexAgent` assumes Codex CLI is already installed, authenticated, and configured for the workspace.

Power should come from composition rather than setup: write a queue, choose an agent, run the loop, and let specialized tools do the work they already know how to do.

## Configuration Defaults

Éminence Grise keeps its own configuration surface small.

`ProcessRunner` uses `require_path: :auto` by default. In that mode, it adds `./lib` to Ruby's load path only when `working_directory/lib` exists. Set `require_path: nil` to disable load-path injection, or pass a string to use an explicit path.

CLI-backed agents assume their tools are already installed, authenticated, and configured. The framework passes task instructions to tools like Codex CLI, Claude Code, and OpenCode; it does not try to own their configuration.

Use `require "eminence_grise"` as the preferred stable public entrypoint. If you need sub-file loading, use canonical paths such as `require "eminence_grise/agents/codex_agent"` or `require "eminence_grise/runner/result_handler"`.

## Architecture

Éminence Grise is a small Ruby gem with a narrow public surface. `lib/eminence_grise.rb` is the canonical require entrypoint and wires together the framework classes. The command-line executable, `exe/eminence-grise`, is intentionally thin: it parses `run`, `stop`, and `status` commands, then delegates process lifecycle work to `EminenceGrise::ProcessRunner`.

The repository is organized around these boundaries:

- `lib/eminence_grise/task.rb` defines `EminenceGrise::Task`, the immutable unit of work. A task has an `id`, `title`, optional `description`, and frozen `metadata`; `with_metadata` returns a new task instead of mutating the original.
- `lib/eminence_grise/memory_queue.rb` provides the current queue adapter, `EminenceGrise::MemoryQueue`, a simple in-process FIFO with `push`, `pop`, `empty?`, and `size`.
- `lib/eminence_grise/runner.rb` owns the sequential task loop. It pops tasks, calls the configured agent, passes structured results to `EminenceGrise::ResultHandler`, logs lifecycle events, and can wait/retry when an execution error exposes `retry_at`.
- `lib/eminence_grise/runner/result_handler.rb` is the bridge from agent output back into the queue. It ignores plain return values, raises failed `AgentResult`s, and enqueues generated follow-up tasks in order.
- `lib/eminence_grise/agents/` contains the callable agent abstraction, orchestration result types, routing support, and CLI-backed adapters for external coding tools.
- `lib/eminence_grise/process_runner.rb` and `lib/eminence_grise/daemon.rb` keep process management separate from task execution. They run loop scripts in the foreground or spawn/detach daemonized Ruby processes with pidfile, stdout, stderr, and framework-log paths.
- `lib/eminence_grise/logging.rb` centralizes logger creation and coercion. Framework components receive logger objects instead of depending on a global logger.
- `examples/` contains runnable loop scripts for the in-process agent path, orchestration, and the Codex, Claude Code, and OpenCode CLI adapters.
- `spec/` mirrors the same boundaries with RSpec coverage for task execution, orchestration, CLI parsing, process/daemon behavior, logging, require compatibility, and each CLI agent.

At runtime, the core loop is queue -> runner -> agent -> result handler -> queue. `Runner` is deliberately sequential: one task is popped and processed at a time, and the loop continues until the queue is empty or `max_tasks` is reached. This makes the framework easy to reason about while still allowing agents to create additional work.

Agents are plain callables. `EminenceGrise::Agent` wraps a Ruby block, while `EminenceGrise::CliAgent` provides common behavior for external command-line coding agents. CLI-backed agents all build a task instruction, execute a provider command in the configured working directory, capture stdout/stderr/status, optionally stream output, extract provider retry times, and raise provider-specific execution errors on failure.

`EminenceGrise::AgentResult` is the orchestration boundary. Plain return values mean the task is complete with no follow-up work. Structured results can be `:complete`, `:split`, `:delegated`, or `:failed`; split and delegated results carry tasks that the result handler appends to the same queue. Delegation is implemented as metadata: `AgentResult.delegated(task, to: :docs)` returns a new task with `metadata[:agent]` set.

Routing is handled by `EminenceGrise::AgentRegistry` and `EminenceGrise::RouterAgent`. The registry maps symbolic names to agent instances. The router chooses an agent from a routing block or a default, then dispatches the task. Missing routes and unknown registered names raise `RouterAgent::RoutingError`.

Process lifecycle is outside the runner. `ProcessRunner` can `load` a loop script in the foreground with temporary load-path setup, or construct a Ruby command and hand it to `Daemon` for background execution. `Daemon` is the low-level pidfile wrapper around `Process.spawn`, `Process.detach`, process liveness checks, and termination.

Logging is intentionally dependency-light. `EminenceGrise::Logging` builds standard Ruby `Logger` instances for console output, files, null output, text formatting, and JSON lines. Foreground process runs default to console logging; daemon runs default to `.eminence-grise/runner.log`, with stdout and stderr redirected separately.

## Shape

The first version is intentionally small:

- `EminenceGrise::Task` describes a unit of work.
- `EminenceGrise::MemoryQueue` provides a simple FIFO task source.
- `EminenceGrise::Agent` wraps the callable that performs the work.
- `EminenceGrise::CliAgent` provides shared behavior for CLI-backed coding agents.
- `EminenceGrise::CodexAgent` runs a task through Codex CLI.
- `EminenceGrise::ClaudeCodeAgent` runs a task through Claude Code.
- `EminenceGrise::OpenCodeAgent` runs a task through OpenCode.
- `EminenceGrise::Logging` creates console, file, null, text, and JSON loggers.
- `EminenceGrise::Runner` fetches tasks from the queue and asks the agent to process them sequentially.
- `EminenceGrise::ProcessRunner` runs a loop script in the foreground or as a daemon.
- `EminenceGrise::Daemon` provides low-level pidfile-backed process management.

## Framework API

Use the framework directly when you want to own the process lifecycle:

```ruby
queue = EminenceGrise::MemoryQueue.new([
  EminenceGrise::Task.new(id: "task-1", title: "Write docs")
])

agent = EminenceGrise::Agent.new do |task|
  puts "Working on #{task.title}"
end

EminenceGrise::Runner.new(queue: queue, agent: agent).run
```

Or hand each task to Codex CLI:

```ruby
agent = EminenceGrise::CodexAgent.new(
  working_directory: Dir.pwd,
  sandbox: "workspace-write",
  approval_policy: "never"
)

EminenceGrise::Runner.new(queue: queue, agent: agent, logger: $stdout).run
```

## CLI Agents

Éminence Grise can delegate tasks to external coding CLIs. These agents share the same task instruction format and return the same result shape.

The CLI tools are expected to be installed, authenticated, and configured outside the framework. The framework stays small: it builds an instruction, invokes the CLI in the chosen working directory, and exposes `stdout`, `stderr`, `status`, and `retry_at` on the result surface.

```ruby
agent = EminenceGrise::CodexAgent.new(working_directory: Dir.pwd)
agent = EminenceGrise::ClaudeCodeAgent.new(working_directory: Dir.pwd)
agent = EminenceGrise::OpenCodeAgent.new(working_directory: Dir.pwd)
```

`CodexAgent` runs `codex exec`. `ClaudeCodeAgent` runs `claude -p`. `OpenCodeAgent` runs `opencode run`.

CLI-agent output is captured in the returned result by default. The runner treats plain return values, including CLI results, as completed work and does not print them. Use `stream: true` when you want stdout and stderr to be shown while the external tool runs:

```ruby
agent = EminenceGrise::CodexAgent.new(
  working_directory: Dir.pwd,
  stream: true
)
```

Codex and similar CLIs often write progress to stderr, so foreground examples stream stderr too. If the CLI is noisy, silence live stderr while still capturing it for failures:

```ruby
agent = EminenceGrise::CodexAgent.new(
  working_directory: Dir.pwd,
  stream: true,
  stderr: nil
)
```

You can also redirect child-process output to files by passing IO objects:

```ruby
FileUtils.mkdir_p(".eminence-grise")

File.open(".eminence-grise/codex.out.log", "a") do |stdout|
  File.open(".eminence-grise/codex.err.log", "a") do |stderr|
    agent = EminenceGrise::CodexAgent.new(working_directory: Dir.pwd, stream: true, stdout: stdout, stderr: stderr)
    EminenceGrise::Runner.new(queue: queue, agent: agent, logger: EminenceGrise::Logging.console).run
  end
end
```

`CliAgent` uses `Open3.capture3` by default and `Open3.popen3` when streaming. In both modes Ruby waits for the child process to finish before `runner.run` continues. If a provider CLI chooses to spawn its own detached background work, that is provider behavior outside the Ruby child process contract.

Claude Code can be configured with the options users normally reach for:

```ruby
agent = EminenceGrise::ClaudeCodeAgent.new(
  working_directory: Dir.pwd,
  model: "sonnet",
  permission_mode: "acceptEdits",
  output_format: "text",
  extra_args: ["--max-turns", "3"]
)
```

Use `output_format: "json"` if you want Claude Code to emit JSON. Éminence Grise does not parse that JSON yet; it remains available as `result.stdout`.

Examples are available in `examples/codex_loop.rb`, `examples/claude_code_loop.rb`, and `examples/opencode_loop.rb`.

## Orchestration

Agents can return `AgentResult` objects to create more work. The runner appends generated tasks to the queue and continues processing sequentially.

```ruby
planner = EminenceGrise::Agent.new do |task|
  EminenceGrise::AgentResult.split([
    EminenceGrise::Task.new(id: "#{task.id}-code", title: "Implement #{task.title}"),
    EminenceGrise::Task.new(id: "#{task.id}-docs", title: "Document #{task.title}")
  ])
end

EminenceGrise::Runner.new(queue: queue, agent: planner).run
```

Specialist agents can be registered and selected by a router:

```ruby
registry = EminenceGrise::AgentRegistry.new
registry.register(:docs, docs_agent)
registry.register(:code, code_agent)

router = EminenceGrise::RouterAgent.new(registry: registry, default: :code) do |task|
  task.metadata[:agent]
end
```

A planner can also delegate by returning a routed task:

```ruby
EminenceGrise::AgentResult.delegated(task, to: :docs)
```

Valid `AgentResult` statuses are `:complete`, `:split`, `:delegated`, and `:failed`. Unknown statuses raise `ArgumentError`.

`RouterAgent` raises `RouterAgent::RoutingError` when a task has no route or when the selected agent has not been registered.

## Logging

Éminence Grise uses Ruby's standard `Logger`.

```ruby
logger = EminenceGrise::Logging.console
logger = EminenceGrise::Logging.file(".eminence-grise/runner.log")
logger = EminenceGrise::Logging.file(".eminence-grise/runner.jsonl", format: :json)
logger = EminenceGrise::Logging.null
```

Pass a logger to `Runner`:

```ruby
runner = EminenceGrise::Runner.new(
  queue: queue,
  agent: agent,
  logger: EminenceGrise::Logging.console
)
```

Foreground process runs default to console logging. Daemon runs default to `.eminence-grise/runner.log`.

Daemon stdout and stderr are still captured separately in `.eminence-grise/runner.out.log` and `.eminence-grise/runner.err.log`. Those files capture process output; the framework log is where runner, retry, routing, and daemon lifecycle events belong.

## Process API

Use `ProcessRunner` when you want Éminence Grise to run a loop script for you:

```ruby
process = EminenceGrise::ProcessRunner.new(script: "examples/codex_loop.rb")

process.run_foreground
process.start_daemon
process.daemon_running?
process.stop_daemon
```

## Try It

```sh
bundle install
ruby -I./lib examples/basic_loop.rb
ruby -I./lib examples/orchestration_loop.rb
rake spec
```

The external CLI examples actually invoke coding agents against this repository:

```sh
ruby -I./lib examples/codex_loop.rb
ruby -I./lib examples/claude_code_loop.rb
ruby -I./lib examples/opencode_loop.rb
```

Run these from the repository root; the examples use `Dir.pwd` as the agent working directory. They are intended as smoke tests and ask the external agent to print a short summary rather than modify files.

## Running A Loop

The executable is a thin wrapper around `EminenceGrise::ProcessRunner`.

Run a loop script in the foreground:

```sh
ruby -I./lib exe/eminence-grise run examples/basic_loop.rb
```

Run a loop script in the background:

```sh
ruby -I./lib exe/eminence-grise run examples/codex_loop.rb --background
```

By default, background runs write:

- pid: `.eminence-grise/runner.pid`
- log: `.eminence-grise/runner.log`
- stdout: `.eminence-grise/runner.out.log`
- stderr: `.eminence-grise/runner.err.log`

Check or stop a background process:

```sh
ruby -I./lib exe/eminence-grise status
ruby -I./lib exe/eminence-grise stop
```

Configure daemon logs:

```sh
ruby -I./lib exe/eminence-grise run examples/codex_loop.rb --background --log .eminence-grise/runner.jsonl --log-format json --log-level info
```

## Retry Times

CLI-backed agents share retry-time extraction through `CliAgent`. When Codex CLI, Claude Code, or OpenCode output includes a retry or resume time, the raised execution error exposes that time as `retry_at`. `Runner` waits until that time and retries the same task by default.

```ruby
runner = EminenceGrise::Runner.new(
  queue: queue,
  agent: agent,
  wait_on_retry_at: true
)
```

Set `wait_on_retry_at: false` if you want retry-time errors to bubble up immediately.

## Failure Behavior

CLI adapters raise provider-specific execution errors when their command fails: `CodexAgent::ExecutionError`, `ClaudeCodeAgent::ExecutionError`, and `OpenCodeAgent::ExecutionError`. Each wraps the shared CLI result surface: `stdout`, `stderr`, `status`, and `retry_at`.

If the external command is not available on `PATH`, the adapter raises the same provider-specific execution error with a `command not found` message. Pass `command:` when the CLI lives at a specific path.

`AgentResult.failed(...)` causes the runner to raise. Routing failures raise `RouterAgent::RoutingError`.

## Direction

The framework should stay easy to reason about while growing toward real coding-agent workflows. Likely next pieces:

- persistent queue adapters
- task state and retries
- workspace/context objects
- tool execution boundaries
- structured agent results
- event hooks for logging and observability
