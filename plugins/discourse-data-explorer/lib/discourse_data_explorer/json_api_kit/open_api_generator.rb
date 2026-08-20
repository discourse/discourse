# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # Derives an OpenAPI 3.1 document from the Kit's declarations — resources
    # (typed attributes, relationships, query surface), the version registry
    # (info.version = the advertised date), and service contracts (request-body
    # schemas from attribute types + validators). Documentation is generated,
    # never authored: the same declarations feed the API and its docs, so they
    # cannot drift — and the drift-proof loop (open_api_document_spec.rb)
    # validates live responses against the generated schemas.
    # See docs/api-docs-generation.md.
    #
    # The document self-assembles: endpoints come from the route table (paths, member
    # paths and which actions exist), each endpoint's shape from its resource class,
    # and request-body constraints from the service a controller declares with
    # `service_for`. Nothing is passed in but the intro prose and captured examples.
    class OpenApiGenerator
      CONTENT_TYPE = "application/vnd.api+json"

      # ActiveModel::Type names → JSON Schema. Attributes render as nullable
      # variants of these (no `null: false` declaration exists yet); parameters
      # and request bodies use them as-is.
      TYPE_SCHEMAS = {
        string: {
          "type" => "string",
        },
        integer: {
          "type" => "integer",
        },
        big_integer: {
          "type" => "integer",
        },
        float: {
          "type" => "number",
        },
        decimal: {
          "type" => "number",
        },
        boolean: {
          "type" => "boolean",
        },
        date: {
          "type" => "string",
          "format" => "date",
        },
        datetime: {
          "type" => "string",
          "format" => "date-time",
        },
        immutable_string: {
          "type" => "string",
        },
        time: {
          "type" => "string",
        },
        array: {
          "type" => "array",
        },
      }.freeze

      # The existing API key credentials, unchanged by the Kit.
      SECURITY_SCHEMES = {
        "ApiKey" => {
          "type" => "apiKey",
          "in" => "header",
          "name" => "Api-Key",
        },
        "ApiUsername" => {
          "type" => "apiKey",
          "in" => "header",
          "name" => "Api-Username",
        },
      }.freeze

      ERRORS_SCHEMA = {
        "type" => "object",
        "properties" => {
          "errors" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "properties" => {
                "status" => {
                  "type" => "string",
                },
                "code" => {
                  "type" => "string",
                },
                "title" => {
                  "type" => "string",
                },
                "detail" => {
                  "type" => "string",
                },
                "source" => {
                  "type" => "object",
                },
                "meta" => {
                  "type" => "object",
                },
                "links" => {
                  "type" => "object",
                },
              },
              "additionalProperties" => false,
            },
          },
        },
        "required" => ["errors"],
        "additionalProperties" => false,
      }.freeze

      # `examples` are captured live exchanges keyed by operationId → status
      # (plus "request" for the request body); see open_api_examples_spec.rb.
      #
      # `scope` is the ownership projection (docs/api-docs-generation.md §8):
      # `:site` composes everything registered — what this installation serves;
      # `:core` keeps only core-owned surfaces — true for every Discourse.
      # Plugin documents are the third projection, via #document_for.
      def initialize(intro: nil, examples: {}, scope: :site)
        @intro = intro
        @examples = examples
        @scope = scope
      end

      # Every routed Kit endpoint, keyed by controller: its collection path, its member
      # path, and the actions the routes actually expose. Internal endpoints are not
      # part of the published surface (docs/resource-design.md §9), so the document
      # never sees them.
      def endpoints
        @endpoints ||=
          Rails
            .application
            .routes
            .routes
            .each_with_object({}) do |route, found|
              controller = route.defaults[:controller].to_s
              action = route.defaults[:action].to_s
              next if !controller.include?("json_api_kit")
              klass = "#{controller}_controller".camelize.safe_constantize
              next if klass.nil? || !(klass < BaseController) || klass.internal?

              path = route.path.spec.to_s.sub("(.:format)", "").gsub(":id", "{id}")
              endpoint = (found[klass] ||= { controller: klass, actions: [] })
              endpoint[:actions] |= [action.to_sym]
              endpoint[path.include?("{id}") ? :member_path : :path] = path
            end
            .values
      end

      # Removed operations are absent from the latest document — new integrators
      # never see them.
      def document = apply_removals(raw_document, gap: [])

      # The document as a client pinned at `version` experiences it: schemas,
      # query-surface parameters, and examples down-migrated through the gap —
      # the same transform philosophy as responses, applied to the docs. Purely
      # additive changes rightly remain visible at every pin (they are not
      # version-gated).
      def document_at(version)
        parsed = ApiVersion.parse(version)
        gap = JsonApiKit.api_versions.gap_for(parsed)
        versioned = raw_document.deep_dup
        versioned["info"]["version"] = parsed.to_s
        return apply_removals(versioned, gap:) if gap.empty?

        resources.each_key do |type|
          downgrade_attributes!(
            versioned.dig("components", "schemas", type, "properties", "attributes"),
            type,
            gap,
          )
        end
        endpoints.each { downgrade_endpoint!(versioned, it, gap) }
        downgrade_examples!(versioned, gap)
        apply_removals(versioned, gap:)
      end

      # One plugin's document — the third ownership projection
      # (docs/api-docs-generation.md §8): its resource schemas, the core
      # endpoints it touches shown with only its contributions, and its own
      # changelog on its own timeline. `at:` pins the document to one of the
      # plugin's OWN versions — the downgrade runs through its own gap only
      # (base-governed surfaces never move with a plugin pin).
      def document_for(namespace, at: nil)
        plugin = JsonApiKit.plugins.fetch(namespace)
        entries = plugin_changelog_entries(plugin)
        description = [plugin_intro(plugin), changelog_markdown(entries)].compact.join("\n\n")
        document = {
          "openapi" => "3.1.0",
          "info" => {
            "title" => "Discourse JSON:API — #{namespace} plugin",
            "version" => JsonApiKit.api_versions.versions_for(namespace).last.to_s,
            "description" => description,
          },
          "x-changelog" => entries,
          "tags" => plugin_tags(plugin),
          "paths" => plugin_paths(plugin),
          "components" => {
            "schemas" => plugin_schemas(plugin),
          },
        }
        return document if at.nil?

        version = ApiVersion.parse(at)
        document["info"]["version"] = version.to_s
        downgrade_plugin!(document, plugin, version)
      end

      private

      def raw_document
        info = {
          "title" => "Discourse JSON:API",
          "version" => JsonApiKit.api_versions.current_version.to_s,
        }
        description = [@intro, changelog_markdown].compact.join("\n\n")
        info["description"] = description if description.present?
        {
          "openapi" => "3.1.0",
          "info" => info,
          "x-changelog" => changelog_entries,
          # Both credentials are required, so one requirement listing both.
          "security" => [{ "ApiKey" => [], "ApiUsername" => [] }],
          "tags" => tags,
          "paths" => paths,
          "components" => {
            "schemas" => schemas,
            "securitySchemes" => SECURITY_SCHEMES,
          },
        }
      end

      # Removal is a timeline fact: an operation whose removal sits in the
      # caller's gap (pinned before it) stays, marked deprecated; otherwise it
      # disappears from the document — mirroring the runtime gate exactly.
      def apply_removals(document, gap:)
        endpoints.each do |endpoint|
          {
            endpoint[:path] => {
              "get" => :index,
              "post" => :create,
            },
            endpoint[:member_path] => {
              "get" => :show,
            },
          }.compact.each do |path, actions|
            operations = document["paths"][path]
            next if operations.nil?

            actions.each do |method, action|
              removal =
                JsonApiKit.api_versions.endpoint_removal(
                  endpoint[:controller].controller_path,
                  action,
                )
              next if removal.nil? || operations[method].nil?

              if gap.include?(removal[:change])
                operations[method]["deprecated"] = true
              else
                operations.delete(method)
              end
            end
            document["paths"].delete(path) if operations.empty?
          end
        end
        document
      end

      # Every resource reachable from the endpoints' primaries through declared
      # relationships, keyed by JSON:API type.
      def resources
        @resources ||=
          begin
            found = {}
            queue = endpoints.map { primary_resource(it) }
            while (resource = queue.shift)
              type = resource.record_type.to_s
              next if found.key?(type)
              found[type] = resource
              queue.concat(relationship_definitions(resource).values.map { it[:resource] })
            end
            found
          end
      end

      def primary_resource(endpoint) = endpoint[:controller]._jsonapi_config.serializer_class

      # A relationship named after a registered namespace is that plugin's
      # contribution (the name IS the namespace, by design) — excluded from the
      # core projection.
      def relationship_definitions(resource)
        definitions =
          resource.respond_to?(:relationship_definitions) ? resource.relationship_definitions : {}
        return definitions if @scope == :site
        definitions.reject { |name, _| JsonApiKit.plugins.key?(name.to_s) }
      end

      def attribute_definitions(resource)
        resource.respond_to?(:attribute_definitions) ? resource.attribute_definitions : {}
      end

      # One tag per endpoint primary, described by the resource itself.
      def tags
        endpoints
          .map do |endpoint|
            resource = primary_resource(endpoint)
            tag = { "name" => tag_name(resource) }
            tag["description"] = resource.description if resource.respond_to?(:description) &&
              resource.description
            tag
          end
          .uniq
      end

      def tag_name(resource) = resource.record_type.to_s.humanize

      def singular(resource) = resource.record_type.to_s.singularize

      # The registry is a dated changelog — descriptions are mandatory on every
      # change. Newest first, one chronological list across owners (defaults
      # resolve one date against every timeline); plugin-owned entries carry
      # their component so readers and machines can tell the clocks apart.
      def changelog_entries
        @changelog_entries ||=
          begin
            changes = JsonApiKit.api_versions.changes
            changes = changes.select { JsonApiKit.api_versions.owner_of(it).nil? } if @scope ==
              :core
            build_changelog(changes)
          end
      end

      def build_changelog(changes)
        changes
          .group_by { it.version.to_s }
          .map do |version, grouped|
            { "version" => version, "changes" => grouped.map { changelog_change(it) } }
          end
          .reverse
      end

      def changelog_change(change)
        entry = { "description" => change.description }
        owner = JsonApiKit.api_versions.owner_of(change)
        entry["component"] = owner if owner
        entry
      end

      def changelog_markdown(entries = changelog_entries)
        return if entries.empty?

        sections =
          entries.map do |entry|
            lines =
              entry["changes"].map do |change|
                prefix = change["component"] ? "`#{change["component"]}`: " : ""
                "- #{prefix}#{change["description"]}"
              end
            "## #{entry["version"]}\n\n#{lines.join("\n")}"
          end
        "# Changelog\n\n#{sections.join("\n\n")}"
      end

      def deprecated?(resource, action)
        resource.respond_to?(:deprecated_actions) && resource.deprecated_actions.key?(action)
      end

      # ── The plugin projection (#document_for) ──

      # Its own changes only — the component label is redundant inside its own
      # document.
      def plugin_changelog_entries(plugin)
        changes =
          JsonApiKit.api_versions.changes.select do
            JsonApiKit.api_versions.owner_of(it) == plugin.namespace
          end
        build_changelog(changes).each { |entry| entry["changes"].each { it.delete("component") } }
      end

      def plugin_intro(plugin)
        namespace = plugin.namespace
        current = JsonApiKit.api_versions.versions_for(namespace).last
        <<~MD
          What the `#{namespace}` plugin adds to the Discourse JSON:API. This document
          covers only the plugin's contributions — the core document describes the full
          endpoints.

          The plugin rides its own timeline: it stays frozen at your base pin unless an
          override names it — `Api-Version: #{JsonApiKit.api_versions.current_version}; #{namespace}=#{current}`.
        MD
      end

      def plugin_tags(plugin)
        endpoints
          .filter_map do |endpoint|
            resource = primary_resource(endpoint)
            next if !plugin.attached_types.include?(resource.record_type.to_s)
            { "name" => tag_name(resource) }
          end
          .uniq
      end

      def plugin_paths(plugin)
        endpoints.each_with_object({}) do |endpoint, result|
          resource = primary_resource(endpoint)
          next if !plugin.attached_types.include?(resource.record_type.to_s)
          result[endpoint[:path]] = { "get" => contribution_operation(endpoint, plugin) }
        end
      end

      # A valid-but-partial operation: only what the plugin adds to the core
      # endpoint, with prose pointing at the core document for the rest. The
      # operationId is the plugin's own (captured examples key on it).
      def contribution_operation(endpoint, plugin)
        resource = primary_resource(endpoint)
        type = resource.record_type.to_s
        related = plugin.relationships[type][:resource]
        with_examples(
          {
            "tags" => [tag_name(resource)],
            "summary" => "List #{type.humanize.downcase} — #{plugin.namespace} contributions",
            "operationId" => "list#{type.camelize}#{plugin.namespace.tr("-", "_").camelize}",
            "description" => contribution_description(plugin, type),
            "parameters" => [
              version_header_parameter,
              *plugin.filters_for(type).map { |name, defn| filter_parameter(name, defn) },
              list_parameter("include", [plugin.namespace]),
              list_parameter(
                "fields[#{related.record_type}]",
                attribute_definitions(related).keys.map(&:to_s),
              ),
            ],
            "responses" => {
              "200" =>
                json_response(
                  "With `include=#{plugin.namespace}`, the plugin's resources appear in " \
                    "the collection document's `included`.",
                  {
                    "type" => "object",
                    "properties" => {
                      "included" => {
                        "type" => "array",
                        "items" => resource_ref(related),
                      },
                    },
                  },
                ),
            },
          },
        )
      end

      def contribution_description(plugin, type)
        relationship = plugin.relationships[type]
        description =
          "Query-surface parameters the `#{plugin.namespace}` plugin adds to this " \
            "endpoint. Each #{type.singularize} gains an include-gated " \
            "`#{plugin.namespace}` relationship"
        return "#{description}." if relationship[:description].blank?
        "#{description} — #{relationship[:description]}"
      end

      def plugin_schemas(plugin)
        plugin
          .relationships
          .values
          .map { it[:resource] }
          .uniq
          .to_h { [it.record_type.to_s, resource_schema(it)] }
      end

      def downgrade_plugin!(document, plugin, version)
        gap =
          JsonApiKit
            .api_versions
            .changes
            .select do
              JsonApiKit.api_versions.owner_of(it) == plugin.namespace && it.version > version
            end
            .reverse
        return document if gap.empty?

        document
          .dig("components", "schemas")
          .each_key do |type|
            downgrade_attributes!(
              document.dig("components", "schemas", type, "properties", "attributes"),
              type,
              gap,
            )
          end
        endpoints.each do |endpoint|
          operation = document.dig("paths", endpoint[:path], "get")
          next if operation.nil?
          downgrade_parameters!(
            operation["parameters"],
            primary_resource(endpoint).record_type.to_s,
            endpoint[:controller]._jsonapi_config,
            gap,
          )
          media_targets(operation).each do |media|
            media["example"] = downgrade_example(media["example"], gap) if media["example"]
          end
        end
        document
      end

      def schemas
        resources.transform_values { resource_schema(it) }.merge("errors" => ERRORS_SCHEMA)
      end

      def resource_schema(resource)
        schema = {
          "type" => "object",
          "properties" => {
            "id" => {
              "type" => "string",
            },
            "type" => {
              "const" => resource.record_type.to_s,
            },
            "attributes" => {
              "type" => "object",
              "properties" =>
                attribute_definitions(resource).to_h do |name, definition|
                  [name.to_s, attribute_schema(definition)]
                end,
              "additionalProperties" => false,
            },
            "relationships" => {
              "type" => "object",
              "properties" =>
                relationship_definitions(resource).to_h do |name, definition|
                  [name.to_s, relationship_schema(definition)]
                end,
              "additionalProperties" => false,
            },
            "meta" => {
              "type" => "object",
            },
          },
          "required" => %w[id type],
          "additionalProperties" => false,
        }
        if resource.respond_to?(:description) && resource.description
          schema["description"] = resource.description
        end
        schema
      end

      def attribute_schema(definition)
        base = TYPE_SCHEMAS.fetch(definition[:type]) { {} }
        schema = base.merge("type" => [base["type"], "null"].compact)
        schema["description"] = definition[:description] if definition[:description]
        # nil? not truthiness: `false` is a legitimate example for a boolean.
        schema["examples"] = [definition[:example]] if !definition[:example].nil?
        schema
      end

      def relationship_schema(definition)
        related_type = definition[:resource].record_type.to_s
        linkage = {
          "type" => "object",
          "properties" => {
            "id" => {
              "type" => "string",
            },
            "type" => {
              "const" => related_type,
            },
          },
          "required" => %w[id type],
          "additionalProperties" => false,
        }
        data = definition[:kind] == :has_many ? { "type" => "array", "items" => linkage } : linkage
        schema = {
          "type" => "object",
          "properties" => {
            "data" => data,
          },
          "additionalProperties" => false,
        }
        schema["description"] = definition[:description] if definition[:description]
        schema
      end

      def paths
        endpoints.each_with_object({}) do |endpoint, result|
          collection = { "get" => finalize(index_operation(endpoint), endpoint, :index) }
          if endpoint[:actions].include?(:create)
            collection["post"] = finalize(create_operation(endpoint), endpoint, :create)
          end
          result[endpoint[:path]] = collection
          if endpoint[:actions].include?(:show)
            result[endpoint[:member_path]] = {
              "get" => finalize(show_operation(endpoint), endpoint, :show),
            }
          end
        end
      end

      def finalize(operation, endpoint, action)
        operation["deprecated"] = true if deprecated?(primary_resource(endpoint), action)
        # The API key scope a caller needs, derived from the same declarations the
        # runtime enforces (docs/resource-design.md §8). OpenAPI reserves the
        # `security` scopes array for OAuth2, so it rides an extension instead.
        scope = ApiKeyScopes.scope_name(endpoint[:controller], action)
        operation["x-api-scope"] = scope if scope
        with_examples(operation)
      end

      def with_examples(operation)
        captured = @examples[operation["operationId"]] || {}
        captured.each do |status, example|
          target =
            if status == "request"
              operation.dig("requestBody", "content", CONTENT_TYPE)
            else
              operation.dig("responses", status, "content", CONTENT_TYPE)
            end
          target["example"] = example if target
        end
        operation
      end

      def index_operation(endpoint)
        resource = primary_resource(endpoint)
        config = endpoint[:controller]._jsonapi_config
        {
          "tags" => [tag_name(resource)],
          "summary" => "List #{resource.record_type.to_s.humanize.downcase}",
          "operationId" => "list#{resource.record_type.to_s.camelize}",
          "parameters" => [
            version_header_parameter,
            *filter_parameters(resource),
            list_parameter("sort", config.sorts.keys.flat_map { [it, "-#{it}"] }),
            list_parameter("include", config.allowed_includes + plugin_includes(resource)),
            *fieldset_parameters,
            page_size_parameter(config),
            cursor_parameter("page[after]"),
            cursor_parameter("page[before]"),
          ],
          "responses" => {
            "200" => json_response("Paginated collection", collection_document_schema(resource)),
            "400" => error_response,
          },
        }
      end

      def show_operation(endpoint)
        resource = primary_resource(endpoint)
        {
          "tags" => [tag_name(resource)],
          "summary" => "Fetch a #{singular(resource).humanize.downcase}",
          "operationId" => "get#{singular(resource).camelize}",
          "parameters" => [
            version_header_parameter,
            {
              "name" => "id",
              "in" => "path",
              "required" => true,
              "schema" => {
                "type" => "string",
              },
            },
          ],
          "responses" => {
            "200" => json_response("Single resource", single_document_schema(resource)),
            "400" => error_response,
            "404" => {
              "description" => "Not found",
            },
          },
        }
      end

      def create_operation(endpoint)
        resource = primary_resource(endpoint)
        {
          "tags" => [tag_name(resource)],
          "summary" => "Create a #{singular(resource).humanize.downcase}",
          "operationId" => "create#{singular(resource).camelize}",
          "parameters" => [version_header_parameter],
          "requestBody" => {
            "required" => true,
            "content" => {
              CONTENT_TYPE => {
                "schema" => create_request_schema(endpoint, resource),
              },
            },
          },
          "responses" => {
            "201" => json_response("Created resource", single_document_schema(resource)),
            "400" => error_response,
            "422" => error_response,
          },
        }
      end

      # The write document's attributes derive from the service contract
      # (docs/api-docs-generation.md §7): ActiveModel attribute types, minus the
      # relationship-derived `<name>_id(s)` params `jsonapi_deserialize` mints,
      # with validators contributing constraints (presence → required, length →
      # maxLength).
      def create_request_schema(endpoint, resource)
        contract = endpoint[:controller].service(:create).const_get(:Contract)
        relationship_params =
          relationship_definitions(resource).keys.flat_map do
            ["#{it.to_s.singularize}_id", "#{it.to_s.singularize}_ids"]
          end

        properties = {}
        required = []
        contract.attribute_types.each do |name, type|
          next if relationship_params.include?(name)
          property = TYPE_SCHEMAS.fetch(type.type) { {} }.dup
          contract
            .validators_on(name)
            .each do |validator|
              case validator
              when ActiveModel::Validations::PresenceValidator
                required << name
              when ActiveModel::Validations::LengthValidator
                property["maxLength"] = validator.options[:maximum] if validator.options[:maximum]
              end
            end
          example = attribute_definitions(resource).dig(name.to_sym, :example)
          property["examples"] = [example] if example
          properties[name] = property
        end

        attributes = { "type" => "object", "properties" => properties }
        attributes["required"] = required if required.any?
        {
          "type" => "object",
          "properties" => {
            "data" => {
              "type" => "object",
              "properties" => {
                "type" => {
                  "const" => resource.record_type.to_s,
                },
                "attributes" => attributes,
              },
            },
          },
          "required" => ["data"],
        }
      end

      def collection_document_schema(resource)
        schema = {
          "type" => "object",
          "properties" => {
            "data" => {
              "type" => "array",
              "items" => resource_ref(resource),
            },
            "included" => included_schema(resource),
            "meta" => {
              "type" => "object",
            },
            "links" => {
              "type" => "object",
              "properties" => {
                "prev" => {
                  "type" => %w[string null],
                },
                "next" => {
                  "type" => %w[string null],
                },
              },
              "additionalProperties" => false,
            },
          },
          "required" => ["data"],
          "additionalProperties" => false,
        }
        schema["properties"].delete("included") if included_schema(resource).nil?
        schema
      end

      def single_document_schema(resource)
        schema = {
          "type" => "object",
          "properties" => {
            "data" => resource_ref(resource),
            "included" => included_schema(resource),
            "meta" => {
              "type" => "object",
            },
          },
          "required" => ["data"],
          "additionalProperties" => false,
        }
        schema["properties"].delete("included") if included_schema(resource).nil?
        schema
      end

      def included_schema(resource)
        related = resources.values - [resource]
        return if related.empty?
        { "type" => "array", "items" => { "anyOf" => related.map { resource_ref(it) } } }
      end

      def resource_ref(resource)
        { "$ref" => "#/components/schemas/#{resource.record_type}" }
      end

      def version_header_parameter
        {
          "name" => "Api-Version",
          "in" => "header",
          "required" => true,
          "description" =>
            "The pinned API version (snap-down date). The resolved version is echoed back.",
          "schema" => {
            "type" => "string",
            "format" => "date",
          },
        }
      end

      # Plugin filters (auto-namespaced keys) document from the same typed,
      # described declarations as the resource's own — merged from the registry,
      # mirroring the runtime's filter lookup.
      def filter_parameters(resource)
        definitions = resource.filter_definitions
        if @scope == :site
          definitions = definitions.merge(JsonApiKit.plugin_filters_for(resource.record_type))
        end
        definitions.map { |name, definition| filter_parameter(name, definition) }
      end

      def filter_parameter(name, definition)
        parameter = {
          "name" => "filter[#{name}]",
          "in" => "query",
          "schema" => TYPE_SCHEMAS.fetch(definition[:type]) { {} },
        }
        parameter["description"] = definition[:description] if definition[:description]
        parameter
      end

      # Comma-separated multi-value params (sort, include, fields) — OpenAPI's
      # form style with explode:false is the spec-blessed encoding.
      def list_parameter(name, values)
        {
          "name" => name,
          "in" => "query",
          "explode" => false,
          "schema" => {
            "type" => "array",
            "items" => {
              "enum" => values,
            },
          },
        }
      end

      def plugin_includes(resource)
        return [] if @scope != :site
        JsonApiKit.plugin_namespaces_for(resource.record_type)
      end

      def fieldset_parameters
        resources.map do |type, resource|
          list_parameter("fields[#{type}]", attribute_definitions(resource).keys.map(&:to_s))
        end
      end

      def page_size_parameter(config)
        {
          "name" => "page[size]",
          "in" => "query",
          "schema" => {
            "type" => "integer",
            "minimum" => 1,
            "maximum" => config.max_page_size,
          },
        }
      end

      def cursor_parameter(name)
        { "name" => name, "in" => "query", "schema" => { "type" => "string" } }
      end

      def downgrade_endpoint!(versioned, endpoint, gap)
        resource = primary_resource(endpoint)
        config = endpoint[:controller]._jsonapi_config
        type = resource.record_type.to_s
        collection = versioned.dig("paths", endpoint[:path])
        downgrade_parameters!(collection["get"]["parameters"], type, config, gap)
        return if (post = collection["post"]).nil?

        attributes =
          post.dig(
            "requestBody",
            "content",
            CONTENT_TYPE,
            "schema",
            "properties",
            "data",
            "properties",
            "attributes",
          )
        downgrade_attributes!(attributes, type, gap)
        if attributes["required"]
          attributes["required"] = VersionPipeline.down_field_names(
            attributes["required"],
            type:,
            changes: gap,
          ).map(&:to_s)
        end
      end

      def downgrade_attributes!(attributes_schema, type, gap)
        return if attributes_schema&.dig("properties").nil?

        attributes_schema["properties"] = attributes_schema["properties"].to_h do |name, property|
          downgrade_attribute(name, property, type, gap)
        end
      end

      # Walks the gap newest→oldest: renames the key, down-converts declared
      # example values (safe — declared examples are well-formed latest values),
      # and applies the declared `old_type:` so schema and example agree.
      def downgrade_attribute(name, property, type, gap)
        current = name.to_sym
        property = property.dup
        gap.each do |change|
          rename = change.attribute_renames_for(type).find { it[:to] == current }
          next if !rename

          current = rename[:from]
          if rename[:down] && property["examples"]
            property["examples"] = property["examples"].map { rename[:down].call(it) }
          end
          if rename[:old_type]
            base = TYPE_SCHEMAS.fetch(rename[:old_type]) { {} }
            property =
              base.merge("type" => [base["type"], "null"].compact).merge(
                property.slice("description", "examples"),
              )
          end
        end
        [current.to_s, property]
      end

      def downgrade_parameters!(parameters, type, config, gap)
        parameters.each do |parameter|
          case parameter["name"]
          when "sort"
            enum = parameter.dig("schema", "items", "enum")
            parameter["schema"]["items"]["enum"] = enum.map do |entry|
              sign = entry.start_with?("-") ? "-" : ""
              key =
                VersionPipeline.down_sort_keys(
                  [entry.delete_prefix("-")],
                  type:,
                  changes: gap,
                  virtual: config.virtual_sort_keys,
                ).first
              "#{sign}#{key}"
            end
          when /\Afilter\[(.+)\]\z/
            key =
              VersionPipeline.down_filter_keys(
                [Regexp.last_match(1)],
                type:,
                changes: gap,
                virtual: config.virtual_filter_keys,
              ).first
            parameter["name"] = "filter[#{key}]"
          when /\Afields\[(.+)\]\z/
            enum = parameter.dig("schema", "items", "enum")
            parameter["schema"]["items"]["enum"] = VersionPipeline.down_field_names(
              enum,
              type: Regexp.last_match(1),
              changes: gap,
            ).map(&:to_s)
          end
        end
      end

      # Captured examples are real JSON:API documents — the response pipeline
      # down-migrates them as it would any response (converters included).
      def downgrade_examples!(versioned, gap)
        versioned["paths"].each_value do |operations|
          operations.each_value do |operation|
            media_targets(operation).each do |media|
              media["example"] = downgrade_example(media["example"], gap) if media["example"]
            end
          end
        end
      end

      def media_targets(operation)
        targets = [operation.dig("requestBody", "content", CONTENT_TYPE)]
        operation["responses"]&.each_value { targets << it.dig("content", CONTENT_TYPE) }
        targets.compact
      end

      def downgrade_example(example, gap)
        document = example.deep_symbolize_keys
        VersionPipeline.down(document, gap)
        document.deep_stringify_keys
      end

      def json_response(description, schema)
        { "description" => description, "content" => { CONTENT_TYPE => { "schema" => schema } } }
      end

      def error_response
        json_response("Error document", { "$ref" => "#/components/schemas/errors" })
      end
    end
  end
end
