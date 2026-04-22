# frozen_string_literal: true
Fabricator(:web_artifact) do
  user
  post
  name { sequence(:name) { |i| "artifact_#{i}" } }
  html { "<div>Test Content</div>" }
  css { ".test { color: blue; }" }
  js { "console.log('test');" }
  metadata { { public: false } }
end

Fabricator(:web_artifact_key_value) do
  web_artifact
  user
  key { sequence(:key) { |i| "key_#{i}" } }
  value { "value" }
  public { false }
end

Fabricator(:web_artifact_version) do
  web_artifact
  version_number { sequence(:version_number) { |i| i } }
  html { "<div>Version Content</div>" }
  css { ".version { color: red; }" }
  js { "console.log('version');" }
  change_description { "Test change" }
end
