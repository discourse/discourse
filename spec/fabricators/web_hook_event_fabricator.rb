# frozen_string_literal: true

Fabricator(:web_hook_event) do
  web_hook { Fabricate(:web_hook) }
  id 0
  payload { { some_key: "some_value" }.to_json }
  status 0
end
