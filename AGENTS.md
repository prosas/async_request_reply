# AGENTS — Working effectively in this repo

This is a Ruby gem that implements the Asynchronous Request–Reply pattern. The core concerns are: serializing "work" (a chain of method calls), persisting that work, and executing it synchronously or via a pluggable async engine.

## Essential commands

- Run tests (Minitest via Rake)
  - `rake test` (see Rakefile:10-11 and README.md:236-242)
- Build the gem (local)
  - `gem build async_request_reply.gemspec` (mirrors .github/workflows/gem-push.yml:34)

## Code organization and architecture

- Entry point: lib/async_request_reply.rb
  - Autoloads core objects and loads defaults (lib/async_request_reply.rb:6-18)
  - Requires repository adapters and worker engines (lib/async_request_reply.rb:11-14)
- Configuration: lib/async_request_reply/config.rb
  - Defaults: repository_adapter=:io, redis_url, async_engine=:simple_thread_pool, logger STDOUT (config.rb:7-12, 20-24)
  - Adapter/engine resolution (config.rb:35-50)
  - MessagePack extension registry (config.rb:72-80) available via `Config.configure.add_message_pack_factory { ... }`
- Executable method chains: lib/async_request_reply/methods_chain.rb
  - `MethodsChain.run_methods_chain(constant, methods)` executes in order, supports kwargs and a single Proc as block (methods_chain.rb:38-56, esp. 42-53)
- Work unit: lib/async_request_reply/worker.rb
  - Persists itself via repository adapter using MessagePack (worker.rb:123-127, 154-177)
  - Async dispatch: `perform_async`, optional `perform_async_at` (worker.rb:129-138)
  - Execution flow with success/failure follow-ups and logging (worker.rb:193-236)
  - Engine selection: instance engine or configured default (worker.rb:144-147, 255-257)
- Batch orchestration: lib/async_request_reply/worker_in_batch.rb
  - Stores batch state as JSON (not MessagePack) in repository (worker_in_batch.rb:118-124, 216-221)
  - Runs workers sequentially, non-raising (sets `raise_error=false`) (worker_in_batch.rb:155-174, 165)
  - Can enqueue itself for async via a Worker (worker_in_batch.rb:180-185)
- Persistence adapters (lib/async_request_reply/repository_adapters/)
  - Abstract interface: `get`, `del`, `setex(uuid, ttl, payload)` (abstract_repository_adapter.rb:4-13)
  - Redis adapter uses `redis-client` with TTL at write time (redis_repository_adapter.rb:18-21)
  - IO adapter writes to `.async_request_reply/<uuid>`; ignores TTL parameter (i_o_repository_adapter.rb:24-28)
- Async engines (lib/async_request_reply/workers_engine/)
  - SimpleThreadPool: in-process queue with fixed threads; supports `perform_async` only (simple_thread_pool.rb:15-17)
  - Sidekiq: includes Sidekiq::Worker; `perform(async_request_id)` runs the Worker; supports `perform_async_at` via `perform_at` (sidekiq.rb:8-15)

## Control/data flow

1. A Worker is initialized with `class_instance` and a `methods_chain`. It must be `valid?` (worker.rb:36-41) before saving.
2. `save` serializes attributes with MessagePack and writes using `repository_adapter.setex` (worker.rb:123-127, 154-177).
3. `perform_async` enqueues the Worker ID into the configured engine (worker.rb:135-138). Engines must accept an ID and call `Worker.find(id).perform`.
4. `perform` executes the chain, then a success or failure chain. When success/failure `class_instance` is `'self'`, chains run on the previous result (worker.rb:203-218).
5. WorkerInBatch persists its own JSON state and drives a queue of Worker IDs, marking successes/failures and never raising (worker_in_batch.rb:155-174).

## Conventions and patterns

- UUID/key format: Workers use `async_request:<uuid>` (worker.rb:22); batches use `async_request_in_batch:<uuid>` (worker_in_batch.rb:48).
- Method chains: arrays of `[method_name, args]`. A single Proc arg becomes a block; kwargs supported when provided as a Hash in the args array (methods_chain.rb:42-53).
- Serialization:
  - Worker → MessagePack factory with optional custom extension types registered via Config (worker.rb:154-177; config.rb:72-80).
  - WorkerInBatch → JSON string (worker_in_batch.rb:118-124, 216-221).
- Repository adapters are class-style with three methods exactly: `get`, `del`, `setex` (abstract_repository_adapter.rb:4-13). Return values are immediately re-read by callers.
- Engines are class-style with `perform_async(id)`; scheduling (at a datetime) is optional and engine-specific via `perform_async_at(datetime, id)`.

## Testing

- Specs live under `spec/` and use Minitest. Rake runs both `*_test.rb` and `*_spec.rb` globs (Rakefile:3-8).
- Run with `rake test`.

## Gotchas and non-obvious behavior

- Scheduling requires engine support: `Worker#perform_async_at` calls `engine.perform_async_at(datetime, id)` (worker.rb:129-133). The default `SimpleThreadPool` does NOT implement this; Sidekiq does (sidekiq.rb:13-15).
- TTL semantics differ by adapter:
  - Redis honors TTL on write (redis_repository_adapter.rb:18-21).
  - IO adapter ignores TTL; files will persist until manually deleted (i_o_repository_adapter.rb:24-28). This affects `Worker#destroy(ttl)` and any auto-cleanup assumptions.
- Worker vs. Batch serialization mismatch: Worker uses MessagePack; Batch uses JSON. Do not assume a shared serialization layer.
- `Worker#valid?` only checks `class_instance` presence (worker.rb:36-41). Ensure it is set before `save`/`perform`.
- In batches, workers are forced non-raising (`raise_error=false`) so batch processing continues even on errors (worker_in_batch.rb:165).

## Extensibility hints (observed interfaces)

- New repository adapter: implement the three class methods from AbstractRepositoryAdapter (abstract_repository_adapter.rb:4-13). Respect `setex(uuid, ttl, payload)`; callers expect to immediately `get` the same value.
- New async engine: provide class methods `perform_async(id)` and, if you need scheduling, `perform_async_at(datetime, id)`. Your `perform` should resolve the Worker ID to an instance and call `perform` (see sidekiq.rb:8-11 for the minimal flow).
- Custom MessagePack types: use `AsyncRequestReply::Config.configure.add_message_pack_factory` to register extensions (README.md:91-115; config.rb:72-80).

## CI/CD context

- GitHub Actions workflow builds and publishes the gem on pushes/PRs to `main` (gem-push.yml). It runs `gem build` and pushes; no test step is configured (gem-push.yml:28-49).
