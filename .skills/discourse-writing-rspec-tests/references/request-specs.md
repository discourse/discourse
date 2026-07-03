# Request Specs

Discourse uses **request specs** (`spec/requests/`) rather than controller specs to exercise controllers. They drive real HTTP requests against the Rails router, so they verify routing, middleware, controller actions, and response payloads end-to-end.

## File and Top-Level Naming

- **File**: `spec/requests/<resource>_controller_spec.rb` — name after the controller it covers (e.g. `bookmarks_controller_spec.rb` for `BookmarksController`).
- **Top-level**: `RSpec.describe SomeController do` — reference the controller class directly, not a string.

```rb
# frozen_string_literal: true

RSpec.describe BookmarksController do
  fab!(:user)

  describe "#create" do
    # ...
  end
end
```

## Group by Controller Action

**One `describe` block per controller action**, named `"#action_name"`:

```rb
describe "#index" do
end

describe "#create" do
end

describe "#destroy" do
end
```

The `#` prefix follows the instance-method convention from the [RSpec style guide](rspec-style-guide.md). Each action's describe block is the home for all scenarios that hit that action — signed-in vs anonymous, permission variations, parameter variations, etc.

Reserve bare descriptive strings (`describe "extensibility event"`) for cross-cutting concerns that don't map to a single action.

## Scenarios Within an Action

Use `context` blocks for scenarios within an action — pair positive and negative cases:

```rb
describe "#create" do
  before { sign_in(user) }

  it "creates the bookmark" do
    post "/bookmarks.json", params: { bookmarkable_id: post.id, bookmarkable_type: "Post" }
    expect(response.status).to eq(200)
  end

  context "when the user has reached the bookmark limit" do
    before { SiteSetting.max_bookmarks_per_user = 1 }

    it "returns a 400 with an explanatory error" do
      # ...
    end
  end
end
```

Keep nesting to 2 levels max (per the top-level testing principles). If a scenario needs more depth, flatten by encoding it into the `it` description.

## Authentication

Sign in inside the action's `describe` block (or a `context`), not at the top of the file — different actions often have different auth requirements:

```rb
describe "#create" do
  before { sign_in(user) }
  # ...
end
```

For anonymous-user scenarios, omit `sign_in` and assert the expected redirect or 403.

## What to Assert

Request specs verify the **observable HTTP behavior** and any externally visible side effects:

- **Response status**: `expect(response.status).to eq(200)`
- **Response body**: `expect(response.parsed_body["errors"]).to include(...)` — use `parsed_body` for JSON
- **Persisted state**: `expect(Bookmark.find_by(id: bookmark.id)).to eq(nil)` — direct DB checks are fine here, since the controller's job is to mutate state
- **Emitted events / enqueued jobs** when relevant

**Don't** assert on internal method calls (`Controller.any_instance.expects(:foo)`) — that couples the test to implementation. If the response and state are correct, the implementation is correct.

## Issuing Requests

Make real HTTP calls — don't stub the controller:

```rb
get "/bookmarks.json"
post "/bookmarks.json", params: { ... }
put "/bookmarks/#{id}.json", params: { ... }
delete "/bookmarks/#{id}.json"
```

Use the `.json` suffix for JSON endpoints; omit it for HTML endpoints.
