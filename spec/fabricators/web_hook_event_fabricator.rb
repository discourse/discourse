# frozen_string_literal: true

Fabricator(:web_hook_event) do
  web_hook { Fabricate(:web_hook) }
  payload { { some_key: "some_value" }.to_json }
  status 200
end
