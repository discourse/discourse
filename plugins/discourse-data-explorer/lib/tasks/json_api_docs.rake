# frozen_string_literal: true

desc "Generate the JSON:API Kit OpenAPI documents (latest + one per version)"
task "data_explorer:json_api_docs" => :environment do
  plugin_root = File.expand_path("../..", __dir__)
  write = ->(name, payload) do
    path = File.join(plugin_root, name)
    File.write(path, JSON.pretty_generate(payload) + "\n")
    puts "Wrote #{path}"
  end

  write.call("openapi-jsonapi.json", DiscourseDataExplorer::JsonApiKit.openapi_document)
  versions = DiscourseDataExplorer::JsonApiKit.openapi_versions
  versions.each do |version|
    write.call(
      "openapi-jsonapi-#{version}.json",
      DiscourseDataExplorer::JsonApiKit.openapi_document_at(version),
    )
  end
  write.call("openapi-versions.json", versions)

  puts "Preview: serve the plugin directory and open openapi-docs.html, e.g."
  puts "  ruby -run -e httpd plugins/discourse-data-explorer -p 8080"
end
