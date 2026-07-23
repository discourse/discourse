# frozen_string_literal: true

desc "Generate the JSON:API Kit OpenAPI document (openapi-jsonapi.json)"
task "data_explorer:json_api_docs" => :environment do
  path = File.expand_path("../../openapi-jsonapi.json", __dir__)
  File.write(path, JSON.pretty_generate(DiscourseDataExplorer::JsonApiKit.openapi_document) + "\n")
  puts "Wrote #{path}"
  puts "Preview: serve the plugin directory and open openapi-docs.html, e.g."
  puts "  ruby -run -e httpd plugins/discourse-data-explorer -p 8080"
end
