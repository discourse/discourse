# Tracking Helpers

Discourse provides a few block helpers for asserting on side effects produced inside a unit of work. They capture what happened during the block and return the collected data so the test can assert on it.

## `DiscourseEvent.track_events`

Captures `DiscourseEvent.trigger` calls made inside the block. Returns an array of `{ event_name:, params: }` hashes.

```rb
events = DiscourseEvent.track_events { PostDestroyer.new(user, post).destroy }

expect(events.map { |e| e[:event_name] }).to include(:post_destroyed)
```

Filter by event name (and optionally by exact args) by passing them in:

```rb
events =
  DiscourseEvent.track_events(:user_first_visit_to_topic) do
    TopicUser.track_visit!(topic.id, user.id)
  end

expect(events).to be_blank
```

Use `DiscourseEvent.track(event_name, args:) { ... }` (singular) when you only care about the first matching event — it returns the event hash directly instead of an array.

## `MessageBus.track_publish`

Captures `MessageBus.publish` calls made inside the block. Returns an array of `MessageBus::Message` objects, each exposing `channel`, `data`, `user_ids`, `group_ids`, and `client_ids`.

```rb
messages = MessageBus.track_publish { described_class.publish_new(private_message) }

expect(messages.map(&:channel)).to contain_exactly(described_class.user_channel(user_2.id))

data = messages.first.data
expect(data["message_type"]).to eq(described_class::NEW_MESSAGE_TYPE)
```

Pass a channel name to capture only publishes to that channel:

```rb
messages = MessageBus.track_publish(channel) { TopicUser.update_last_read(user, topic.id, 2, 1, 0) }
```

## `track_sql_queries`

Captures the SQL executed by ActiveRecord and MiniSQL inside the block. Returns an array of SQL strings (with `CACHE` and `SCHEMA` queries filtered out). Useful for N+1 regression checks.

```rb
queries_for_one =
  track_sql_queries do
    components.each { |c| ComponentIndexSerializer.new(c, root: false).as_json }
  end

queries_for_two =
  track_sql_queries do
    larger_components.each { |c| ComponentIndexSerializer.new(c, root: false).as_json }
  end

expect(queries_for_two.size).to eq(queries_for_one.size)
```

Compare query *counts* across scaled-up inputs to assert "constant queries regardless of N". Asserting on the exact SQL strings is fragile — prefer counts or shape checks.
