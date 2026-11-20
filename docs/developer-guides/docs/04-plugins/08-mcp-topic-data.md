---
title: Add plugin data to native MCP topics
short_title: MCP topic data
id: mcp-topic-data
---

The `mcp_topic_plugin_data` modifier adds plugin-owned data to `discourse_read_topic`
and `discourse_filter_topics`. It runs once for each returned topic batch.

The modifier receives three arguments:

- `data`: a hash keyed by integer topic ID. Each value is a hash keyed by plugin name.
- `topics`: the array of topics that the native tool has authorized for this request.
- `request_context`: the current `DiscourseMcp::RequestContext`. It provides the
  current `guardian` and delegated scope checks through `has_scopes?` and `ensure_scopes!`.

Return the complete `data` hash. Preserve data from other plugins. Use the plugin
name as a namespace. Do not change the topics or return data for other topic IDs.
Values must be JSON-serializable. Integer hash keys become strings in the response.
The data appears in both text content and structured content. An invalid modifier
return value or an exception fails the tool call.

```ruby
after_initialize do
  register_modifier(:mcp_topic_plugin_data) do |data, topics, request_context|
    next data unless SiteSetting.example_enabled

    topics.each do |topic|
      next unless request_context.guardian.can_edit?(topic)

      data[topic.id] = data.fetch(topic.id, {}).merge(
        "example" => { editable: true },
      )
    end
    data
  end
end
```

A topic's visibility does not grant access to all plugin data. Check the current
user's permissions and any required delegated scopes for each field. Do not return
secrets or email addresses. Check reply visibility before returning data about a
reply. Private-message access also requires the dedicated MCP scope.

Load related records for the whole batch, not once per topic. Omit a namespace when
there is no data that the user can see. Native tools omit `plugin_data` when the
entire topic entry is empty.
