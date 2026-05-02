# Éminence Grise

Éminence Grise is an agentic development framework built in Ruby.

It aims to be simple, but powerful.

It uses a simple architecture and agent loop to allow developers to create agents that can perform coding tasks.

## Shape

The first version is intentionally small:

- `EminenceGrise::Task` describes a unit of work.
- `EminenceGrise::MemoryQueue` provides a simple FIFO task source.
- `EminenceGrise::Agent` wraps the callable that performs the work.
- `EminenceGrise::CodexAgent` runs a task through `codex exec`.
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
ruby -I./lib examples/codex_loop.rb
rake spec
```

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
- stdout: `.eminence-grise/runner.out.log`
- stderr: `.eminence-grise/runner.err.log`

Check or stop a background process:

```sh
ruby -I./lib exe/eminence-grise status
ruby -I./lib exe/eminence-grise stop
```

## Retry Times

When `CodexAgent` sees a failed `codex exec` response that includes a retry or resume time, it exposes that time on the raised error. `Runner` waits until that time and retries the same task by default.

```ruby
runner = EminenceGrise::Runner.new(
  queue: queue,
  agent: agent,
  wait_on_retry_at: true
)
```

Set `wait_on_retry_at: false` if you want retry-time errors to bubble up immediately.

## Direction

The framework should stay easy to reason about while growing toward real coding-agent workflows. Likely next pieces:

- persistent queue adapters
- task state and retries
- workspace/context objects
- tool execution boundaries
- structured agent results
- event hooks for logging and observability
