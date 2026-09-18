---
title: Using the AI bot via the Discourse API
short_title: AI bot via API
id: ai-evals
---

## Overview

Discourse AI exposes an admin/API endpoint for streaming an AI Agent reply over a raw chunked HTTP response.

- **Protocol:** Raw chunked HTTP transfer encoding (NOT Server-Sent Events).
- **Implementation:** Hijacks the Rack socket to stream newline-separated JSON objects.
- **Side Effects:** This is not just a completion API; it creates real Discourse Private Message (PM) posts.

---

## Endpoint Details

- **Location:** `plugins/discourse-ai/app/controllers/discourse_ai/admin/ai_agents_controller.rb:175-272`
- **Route:** `POST /admin/plugins/discourse-ai/ai-agents/stream-reply.json`
- **API Key Scope:** `ai:stream_completion` (registered in `plugins/discourse-ai/lib/ai_bot/entry_point.rb:283-286`)

### Request Headers

```http
POST /admin/plugins/discourse-ai/ai-agents/stream-reply.json
Api-Key: \u003Cyour_api_key\u003E
Api-Username: \u003Cyour_username\u003E
Content-Type: application/json
```

### Request Body Parameters

| Parameter             | Type    | Required                                | Description                                                                                                     |
| :-------------------- | :------ | :-------------------------------------- | :-------------------------------------------------------------------------------------------------------------- |
| `agent_id`            | Integer | Optional\*                              | Identifier for the agent.                                                                                       |
| `agent_name`          | String  | Optional\*                              | Alternative identifier for the agent.                                                                           |
| `query`               | String  | **Yes**                                 | The user's prompt/question.                                                                                     |
| `username`            | String  | Required if `user_unique_id` is omitted | Used incase the chat PM needs to be associated with an existing user.                                           |
| `user_unique_id`      | String  | Required if `username` is omitted       | Identifies the end-user. Creates/reuses a staged user keyed by custom field `ai-stream-conversation-unique-id`. |
| `preferred_username`  | String  | Optional\*                              | Username for the user (if `user_unique_id` is not used).                                                        |
| `topic_id`            | Integer | Optional                                | Continue an existing PM conversation.                                                                           |
| `custom_instructions` | String  | Optional                                | Appended into the agent prompt context.                                                                         |

\u003E **Note:** You must identify the end-user by either `username` (existing Discourse user) or `user_unique_id`.

---

## Response Format

The server returns a `200 OK` response with `Transfer-Encoding: chunked`. The stream consists of newline-separated JSON objects.

### HTTP Headers

```http
HTTP/1.1 200 OK
Content-Type: text/plain; charset=utf-8
Transfer-Encoding: chunked
Cache-Control: no-cache, no-store, must-revalidate
Connection: close
X-Accel-Buffering: no
X-Content-Type-Options: nosniff
```

### Stream Payload Structure

1.  **Context Chunk:** Provides metadata (topic ID, bot user ID, agent ID).
2.  **Partial Chunks:** Contains the streamed text fragments.

**Example Stream:**

```json
{\"topic_id\":42,\"bot_user_id\":7,\"agent_id\":123}

{\"partial\":\"Hello\"}

{\"partial\":\" there\"}
```

_The client should concatenate `partial` fields to build the final answer._

---

## Workflow & Side Effects

The endpoint performs the following actions during execution:

1.  Creates a user post with the raw `query`.
2.  Streams the AI answer via the chunked response.
3.  Creates the final AI reply post with the accumulated answer.
4.  For new PMs, may auto-title the topic.

---

## Custom Client-Executed Tools

You can provide tool definitions to allow the model to call external tools. The server pauses the stream when a tool is called, allowing the client to execute the tool and resume.

### 1. Initial Request with Tools

Include `custom_tools` in the request body:

```json
{
  \"agent_id\": 123,
  \"query\": \"What's the weather?\",
  \"user_unique_id\": \"external-user-42\",
  \"custom_tools\": [
    {
      \"name\": \"client_weather\",
      \"description\": \"Gets weather from the client runtime\",
      \"parameters\": [
        {
          \"name\": \"city\",
          \"description\": \"City to fetch weather for\",
          \"type\": \"string\",
          \"required\": true
        }
      ]
    }
  ]
}
```

### 2. Tool Call Event

If the model calls a tool, the stream emits a `tool_calls` event and stops:

```json
{
  \"event\": \"tool_calls\",
  \"tool_calls\": [
    {
      \"id\": \"tool_1\",
      \"name\": \"client_weather\",
      \"parameters\": { \"city\": \"Austin\" }
    }
  ],
  \"resume_token\": \"...\"
}
```

_The server persists conversation state in Redis at this point._

### 3. Resume with Tool Results

The client executes the tool and resumes the stream:

```json
{
  \"resume_token\": \"...\",
  \"tool_results\": [
    {
      \"tool_call_id\": \"tool_1\",
      \"content\": { \"temperature_c\": 23 }
    }
  ]
}
```

The server reloads the saved prompt state, inserts the tool result, continues generation, and streams more `partial` chunks.

### Tool Limits

- Max custom tools: **20**
- Max tool results: **20**
- Max custom tool definition size: **10,000 bytes**
- Max tool result content size: **100 KB**
- Resume TTL: **15 minutes**
- Max resume rounds: **10**

---

## Implementation References

- **Controller:** `plugins/discourse-ai/app/controllers/discourse_ai/admin/ai_agents_controller.rb`
- **Streamer:** `plugins/discourse-ai/lib/ai_bot/response_http_streamer.rb`
- **Custom Tools Session:** `plugins/discourse-ai/lib/ai_bot/stream_reply_custom_tools_session.rb`

### Test Examples

See `plugins/discourse-ai/spec/requests/admin/ai_agents_controller_spec.rb` for comprehensive examples:

- **New streamed conversation:** Lines 1248-1356
- **Custom tools + resume token:** Lines 1358-1448
- **Parallel tool calls:** Lines 1467-1590\u003Cdiv data-theme-toc=\"true\"\u003E \u003C/div\u003E

### Sample implementation

[details=Ruby Script]

```ruby
require 'net/http'
require 'json'
require 'uri'

# Configuration
DISCOURSE_URL = '\u003Cyour site URL\u003E'
API_KEY = '\u003Cyour API key\u003E'
USERNAME = '\u003Cyour username\u003E'
AGENT_ID = -1 # Or use agent_name
QUERY = \"Hello, how are you today?\"
USER_UNIQUE_ID ='\u003Cleave empty if want the PM to be sent to the USERNAME user\u003E'


# Helper to create the URI
uri = URI(\"#{DISCOURSE_URL}/admin/plugins/discourse-ai/ai-agents/stream-reply.json\")

# Create the HTTP request
request = Net::HTTP::Post.new(uri)
request['Api-Key'] = API_KEY
request['Api-Username'] = USERNAME
request['Content-Type'] = 'application/json'

# Prepare the request body
body = {
  agent_id: AGENT_ID,
  query: QUERY,
  ## uncomment the below line if you want to use an existing user for the conversation. Also, `username` takes precedence over `user_unique_id` if passed.
  # username: USERNAME,
  ## use the below field along with `user_unique_id` in order to create a new staged user. When using this, skip passing the `username`.
  # preferred_username: USER_UNIQUE_ID
}
body[:user_unique_id] = USER_UNIQUE_ID unless USER_UNIQUE_ID.empty?

body = body.to_json
request.body = body

http = Net::HTTP.new(uri.hostname, uri.port)
http.use_ssl = (uri.scheme == 'https')

http.request(request) do |response|
    # Check if the response is successful
    if response.code == '200'
    puts \"Stream started successfully.\"
    puts \"Response headers: #{response.to_hash}\"
    puts \"Streaming content:\"

    # Read the chunked response
    response.read_body do |chunk|
        # The response is newline-separated JSON objects
        chunk.each_line do |line|
        line = line.strip
        next if line.empty?

        begin
            json = JSON.parse(line)

            if json['topic_id']
            puts \"\
--- Context Received ---\"
            puts \"Topic ID: #{json['topic_id']}\"
            puts \"Bot User ID: #{json['bot_user_id']}\"
            puts \"Agent ID: #{json['agent_id']}\"
            elsif json['partial']
            # Stream the partial content
            print json['partial']
            elsif json['event'] == 'tool_calls'
            puts \"\
--- Tool Call Received ---\"
            puts JSON.pretty_generate(json)
            # Here you would handle tool execution and resume
            # For this example, we just print it
            end

            # puts \"\u003Cnew word\u003E\"
        rescue JSON::ParserError =\u003E e
            puts \"\
Error parsing JSON: #{e.message}\"
            puts \"Raw line: #{line}\"
        end
        end
    end
    puts \"\
--- Stream Finished ---\"

    else
    puts \"Error: #{response.code} #{response.message}\"
    puts \"Response body: #{response.body}\"
    end
end
```

[/details]

### Notes

- If you want the conversation to be in the name of a new staged user, pass the `unique_user_id` and `preferred_username` as the new desired username and skip the `username` field.
- If you want to converse using an existing user, pass that user's `username` and skip the `unique_user_id` and `preferred_username` fields.
