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

That gives us a tiny loop:

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

## Try It

```sh
bundle install
ruby -I./lib examples/basic_loop.rb
ruby -I./lib examples/codex_loop.rb
rake spec
```

## Direction

The framework should stay easy to reason about while growing toward real coding-agent workflows. Likely next pieces:

- persistent queue adapters
- task state and retries
- workspace/context objects
- tool execution boundaries
- structured agent results
- event hooks for logging and observability
