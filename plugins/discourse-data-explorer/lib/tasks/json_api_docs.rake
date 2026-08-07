# frozen_string_literal: true

desc "Generate the JSON:API Kit OpenAPI documents (core latest + one per version + one per plugin)"
task "data_explorer:json_api_docs" => :environment do
  plugin_root = File.expand_path("../..", __dir__)
  write = ->(name, payload) do
    path = File.join(plugin_root, name)
    File.write(path, JSON.pretty_generate(payload) + "\n")
    puts "Wrote #{path}"
  end

  # The committed set mirrors the global docs structure (docs/
  # api-docs-generation.md §8): the core document (with its core-timeline
  # versions) plus one document per plugin. The site-composed document
  # (scope: :site) stays spec-proven, not emitted — it is what a live
  # installation would serve.
  write.call(
    "openapi-jsonapi.json",
    DiscourseDataExplorer::JsonApiKit.openapi_document(scope: :core),
  )
  versions = DiscourseDataExplorer::JsonApiKit.openapi_versions
  versions.each do |version|
    write.call(
      "openapi-jsonapi-#{version}.json",
      DiscourseDataExplorer::JsonApiKit.openapi_document_at(version, scope: :core),
    )
  end
  plugins =
    DiscourseDataExplorer::JsonApiKit.plugins.keys.sort.map do |namespace|
      write.call(
        "openapi-jsonapi-plugin-#{namespace}.json",
        DiscourseDataExplorer::JsonApiKit.openapi_document_for(namespace),
      )
      plugin_versions = DiscourseDataExplorer::JsonApiKit.openapi_plugin_versions(namespace)
      plugin_versions.each do |version|
        write.call(
          "openapi-jsonapi-plugin-#{namespace}-#{version}.json",
          DiscourseDataExplorer::JsonApiKit.openapi_document_for(namespace, at: version),
        )
      end
      { "namespace" => namespace, "versions" => plugin_versions }
    end
  write.call("openapi-versions.json", { "versions" => versions, "plugins" => plugins })

  puts "Preview: serve the plugin directory and open openapi-docs.html, e.g."
  puts "  ruby -run -e httpd plugins/discourse-data-explorer -p 8080"
end
