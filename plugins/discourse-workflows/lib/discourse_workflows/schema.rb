# frozen_string_literal: true

require "json_schemer"
require_relative "schema/graph_resolver"

module DiscourseWorkflows
  module Schema
    DRAFT_URI = "https://json-schema.org/draft/2020-12/schema"
    MODES = %i[replace passthrough merge union].freeze

    def self.entity(name, properties, description)
      {
        "$schema" => DRAFT_URI,
        "type" => "object",
        "properties" => {
          name => {
            "type" => "object",
            "description" => description,
            "properties" => properties,
          },
        },
      }.freeze
    end

    def self.document(properties)
      { "$schema" => DRAFT_URI, "type" => "object", "properties" => properties }.freeze
    end

    def self.entity_extension(name, properties)
      {
        "$schema" => DRAFT_URI,
        "type" => "object",
        "properties" => {
          name => {
            "type" => "object",
            "properties" => properties,
          },
        },
      }.freeze
    end

    TOPIC_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "title": { "type": "string" },
        "fancy_title": { "type": "string" },
        "slug": { "type": "string" },
        "archetype": { "type": "string", "description": "regular for topics, private_message for PMs" },
        "posts_count": { "type": "integer" },
        "category_id": { "type": ["integer", "null"] },
        "user_id": { "type": "integer" },
        "tags": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "id": { "type": "integer" },
              "name": { "type": "string" },
              "slug": { "type": "string" }
            }
          }
        },
        "first_post_id": { "type": "integer" },
        "visible": { "type": "boolean" },
        "visibility_reason_id": { "type": "integer" },
        "closed": { "type": "boolean" },
        "archived": { "type": "boolean" },
        "created_at": { "type": "string", "format": "date-time" },
        "last_posted_at": { "type": ["string", "null"], "format": "date-time" },
        "bumped_at": { "type": ["string", "null"], "format": "date-time" }
      }
    JSON

    POST_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "raw": { "type": "string" },
        "raw_truncated": { "type": "boolean" },
        "raw_original_length": { "type": "integer" },
        "cooked": { "type": "string" },
        "cooked_truncated": { "type": "boolean" },
        "cooked_original_length": { "type": "integer" },
        "post_number": { "type": "integer" },
        "post_type": { "type": "integer" },
        "reply_to_post_number": { "type": ["integer", "null"] },
        "topic_id": { "type": "integer" },
        "topic_slug": { "type": "string" },
        "topic_title": { "type": "string" },
        "post_url": { "type": "string" },
        "category_id": { "type": ["integer", "null"] },
        "category_name": { "type": ["string", "null"] },
        "user_id": { "type": "integer" },
        "username": { "type": "string" },
        "created_at": { "type": "string", "format": "date-time" },
        "updated_at": { "type": "string", "format": "date-time" },
        "excerpt": { "type": "string" },
        "like_count": { "type": "integer" },
        "reply_count": { "type": "integer" },
        "score": { "type": ["number", "null"] },
        "tags": { "type": "array", "items": { "type": "string" } },
        "upload_ids": { "type": "array", "items": { "type": "integer" } }
      }
    JSON

    BASIC_USER_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "username": { "type": "string" },
        "name": { "type": ["string", "null"] },
        "avatar_template": { "type": "string" }
      }
    JSON

    USER_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "username": { "type": "string" },
        "name": { "type": ["string", "null"] },
        "trust_level": { "type": "integer" },
        "trust_level_name": { "type": "string" },
        "admin": { "type": "boolean" },
        "moderator": { "type": "boolean" },
        "staff": { "type": "boolean" },
        "created_at": { "type": "string", "format": "date-time" },
        "approved": { "type": "boolean" },
        "silenced": { "type": "boolean" },
        "suspended": { "type": "boolean" },
        "uploaded_avatar_id": { "type": ["integer", "null"] },
        "avatar_template": { "type": "string" }
      }
    JSON

    BASIC_GROUP_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "name": { "type": "string" },
        "full_name": { "type": ["string", "null"] },
        "automatic": { "type": "boolean" }
      }
    JSON

    GROUP_PROPERTIES = BASIC_GROUP_PROPERTIES.merge(JSON.parse(<<~JSON)).freeze
      {
        "user_count": { "type": "integer" },
        "title": { "type": ["string", "null"] },
        "visibility_level": { "type": "integer" },
        "members_visibility_level": { "type": "integer" },
        "mentionable_level": { "type": "integer" },
        "messageable_level": { "type": "integer" },
        "primary_group": { "type": "boolean" },
        "grant_trust_level": { "type": ["integer", "null"] },
        "public_admission": { "type": "boolean" },
        "public_exit": { "type": "boolean" },
        "allow_membership_requests": { "type": "boolean" },
        "default_notification_level": { "type": "integer" },
        "membership_request_template": { "type": ["string", "null"] },
        "can_see_members": { "type": "boolean" },
        "publish_read_state": { "type": "boolean" },
        "flair_url": { "type": ["string", "null"] },
        "flair_bg_color": { "type": ["string", "null"] },
        "flair_color": { "type": ["string", "null"] },
        "bio_cooked": { "type": ["string", "null"] },
        "bio_excerpt": { "type": ["string", "null"] }
      }
    JSON

    TOPIC_LIST_ITEM_SCHEMA = entity("topic", TOPIC_PROPERTIES, "TopicListItemSerializer payload")
    POST_SCHEMA = entity("post", POST_PROPERTIES, "DiscourseWorkflows::PostSerializer payload")
    BASIC_USER_SCHEMA = entity("user", BASIC_USER_PROPERTIES, "BasicUserSerializer payload")
    USER_SCHEMA = entity("user", USER_PROPERTIES, "Basic safe user attributes")
    IP_LOCATION_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "type": ["object", "null"],
        "description": "Derived on demand from the MaxMind databases, null when unavailable",
        "properties": {
          "country": { "type": "string" },
          "country_code": { "type": "string" },
          "region": { "type": ["string", "null"] },
          "city": { "type": ["string", "null"] },
          "location": { "type": "string" },
          "latitude": { "type": ["number", "null"] },
          "longitude": { "type": ["number", "null"] },
          "asn": { "type": ["integer", "null"] },
          "organization": { "type": ["string", "null"] }
        }
      }
    JSON

    USER_ACTION_PROPERTIES = JSON.parse(<<~JSON).freeze
          {
            "title": { "type": ["string", "null"] },
            "bio_raw": { "type": ["string", "null"] },
            "website": { "type": ["string", "null"] },
            "profile_background_upload_id": { "type": ["integer", "null"] },
            "card_background_upload_id": { "type": ["integer", "null"] },
            "manual_locked_trust_level": { "type": ["integer", "null"] },
            "trust_level_locked": { "type": "boolean" },
            "user_fields": { "type": "object" },
            "groups": {
              "type": "array",
              "items": {
                "type": "object",
                "properties": {
                  "id": { "type": "integer" },
                  "name": { "type": "string" },
                  "full_name": { "type": ["string", "null"] },
                  "automatic": { "type": "boolean" }
                }
              }
            }
          }
        JSON

    USER_STATS_PROPERTIES = JSON.parse(<<~JSON).freeze
          {
            "stats": {
              "type": ["object", "null"],
              "properties": {
                "topics_entered": { "type": "integer" },
                "posts_read_count": { "type": "integer" },
                "time_read": { "type": "integer" },
                "days_visited": { "type": "integer" },
                "post_count": { "type": "integer" },
                "topic_count": { "type": "integer" },
                "likes_given": { "type": "integer" },
                "likes_received": { "type": "integer" },
                "first_post_created_at": { "type": ["string", "null"], "format": "date-time" }
              }
            }
          }
        JSON

    USER_EXTENSION_PROPERTIES = {
      "stats" => USER_STATS_PROPERTIES,
      "external_ids" =>
        JSON.parse(
          '{ "external_id": { "type": ["string", "null"] }, "external_ids": { "type": "object" } }',
        ).freeze,
      "emails" =>
        JSON.parse(
          '{ "email": { "type": ["string", "null"] }, "secondary_emails": { "type": "array", "items": { "type": "string" } } }',
        ).freeze,
      "ips" => {
        "registration_ip_address" => {
          "type" => %w[string null],
        },
        "registration_location" => IP_LOCATION_PROPERTIES,
        "ip_address" => {
          "type" => %w[string null],
        },
        "last_location" => IP_LOCATION_PROPERTIES,
      }.freeze,
    }.freeze

    USER_ACTION_SCHEMA =
      entity(
        "user",
        USER_PROPERTIES.merge(USER_ACTION_PROPERTIES),
        "Discourse user lookup/update payload",
      )

    USER_EXTENSION_SCHEMAS =
      USER_EXTENSION_PROPERTIES
        .transform_values { |properties| entity_extension("user", properties) }
        .freeze
    BASIC_GROUP_SCHEMA =
      entity("group", BASIC_GROUP_PROPERTIES, "Group involved in the membership event")
    GROUP_SCHEMA = entity("group", GROUP_PROPERTIES, "WebHookGroupSerializer payload")
    GROUP_MEMBERSHIP_SCHEMA =
      entity("group_membership", JSON.parse(<<~JSON), "Group membership check result")
        {
          "group_id": { "type": "integer" },
          "group_name": { "type": "string" },
          "user_id": { "type": "integer" },
          "username": { "type": "string" },
          "in_group": { "type": "boolean" }
        }
      JSON
    WEBHOOK_REQUEST_SCHEMA = document(JSON.parse(<<~JSON))
          {
            "body": {},
            "headers": { "type": "object" },
            "params": { "type": "object" },
            "query": { "type": "object" },
            "method": { "type": "string" },
            "webhook_url": { "type": "string" },
            "raw_body": { "type": "string" }
          }
        JSON

    def self.group_membership_event(action)
      document(
        USER_SCHEMA
          .fetch("properties")
          .merge(BASIC_GROUP_SCHEMA.fetch("properties"))
          .merge(
            "membership" => {
              "type" => "object",
              "description" => "Group membership event metadata",
              "properties" => {
                "automatic" => {
                  "type" => %w[boolean null],
                },
                "action" => {
                  "const" => action,
                },
              },
            },
          ),
      )
    end

    USER_ADDED_TO_GROUP_SCHEMA = group_membership_event("added")
    USER_REMOVED_FROM_GROUP_SCHEMA = group_membership_event("removed")

    USER_EVENT_SCHEMA =
      entity(
        "user",
        USER_PROPERTIES.merge(
          "staged" => {
            "type" => "boolean",
          },
          "created_at" => {
            "type" => "string",
            "format" => "date-time",
          },
        ),
        "User account event payload",
      )

    USER_UPDATED_EVENT_SCHEMA =
      document(
        USER_EVENT_SCHEMA.fetch("properties").merge(
          "changed" => {
            "type" => %w[array null],
            "description" =>
              "Which parts of the profile changed, or null when the update did not report it",
            "items" => {
              "type" => "string",
            },
          },
        ),
      )

    USER_SEEN_SCHEMA =
      document(
        BASIC_USER_SCHEMA.fetch("properties").merge(
          "seen" => {
            "type" => "object",
            "description" => "User seen event details",
            "properties" => {
              "first_seen" => {
                "type" => "boolean",
              },
              "current_seen_at" => {
                "type" => %w[string null],
                "format" => "date-time",
              },
              "previous_seen_at" => {
                "type" => %w[string null],
                "format" => "date-time",
              },
              "seconds_since_previous_seen" => {
                "type" => %w[integer null],
              },
            },
          },
        ),
      )

    REVIEWABLE_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "type": { "type": "string" },
        "status": { "type": "string" },
        "target_type": { "type": ["string", "null"] },
        "target_id": { "type": ["integer", "null"] },
        "topic_id": { "type": ["integer", "null"] },
        "category_id": { "type": ["integer", "null"] },
        "score": { "type": "number" },
        "created_at": { "type": ["string", "null"], "format": "date-time" }
      }
    JSON

    REVIEWABLE_EVENT_SCHEMA =
      entity("reviewable", REVIEWABLE_PROPERTIES, "Review queue item payload")

    TAG_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "name": { "type": "string" },
        "slug": { "type": "string" },
        "topic_count": { "type": "integer" },
        "staff": { "type": "boolean" },
        "description": { "type": ["string", "null"] },
        "description_cooked": { "type": ["string", "null"] }
      }
    JSON

    TAG_SCHEMA = entity("tag", TAG_PROPERTIES, "Tag created by Discourse")

    BADGE_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "name": { "type": "string" },
        "description": { "type": ["string", "null"] },
        "badge_type_id": { "type": "integer" },
        "icon": { "type": ["string", "null"] },
        "image_url": { "type": ["string", "null"] },
        "grant_count": { "type": "integer" },
        "system": { "type": "boolean" },
        "multiple_grant": { "type": "boolean" }
      }
    JSON

    BADGE_SCHEMA = entity("badge", BADGE_PROPERTIES, "Badge involved in the grant event")
    BADGE_GRANTED_SCHEMA =
      document(USER_SCHEMA.fetch("properties").merge(BADGE_SCHEMA.fetch("properties")))

    class << self
      def normalize(schema)
        return {} if schema.blank?

        raise ArgumentError, "Output schema must be a JSON Schema object" unless schema.is_a?(Hash)

        schema = schema.deep_stringify_keys
        unless schema["$schema"] == DRAFT_URI
          raise ArgumentError, "Output schema must declare JSON Schema Draft 2020-12"
        end
        unless JSONSchemer.valid_schema?(schema)
          raise ArgumentError, "Output schema is not valid JSON Schema Draft 2020-12"
        end

        schema
      end

      def merge(*schemas)
        schemas = schemas.flatten.map { |schema| stringify(schema) }.reject(&:empty?)
        schemas.reduce({}) { |combined, schema| merge_pair(combined, schema) }
      end

      def unknown?(schema)
        stringify(schema).empty?
      end

      def union(*schemas)
        schemas = schemas.flatten.map { |schema| stringify(schema) }
        return {} if schemas.empty? || schemas.any? { |schema| unknown?(schema) }

        branches = schemas.flat_map { |schema| union_branches(schema) }.uniq
        return branches.first if branches.one?

        { "$schema" => DRAFT_URI, "anyOf" => branches }
      end

      def augment(schema, *extensions)
        extensions = extensions.flatten.map { |extension| stringify(extension) }.reject(&:empty?)
        return schema if extensions.empty?

        schema = stringify(schema)
        if any_of_wrapper?(schema)
          return union(*union_branches(schema).map { |branch| augment(branch, extensions) })
        end

        extensions.reduce(schema) { |merged, extension| merge_pair(merged, extension) }
      end

      def resolve(schema, mode:, input_schema: {})
        mode = mode&.to_sym
        raise ArgumentError, "Unknown output schema mode: #{mode.inspect}" if MODES.exclude?(mode)

        case mode
        when :passthrough
          input_schema
        when :union
          union(input_schema, schema)
        when :merge
          overlay(stringify(input_schema), stringify(schema))
        else
          schema
        end
      end

      def resolve_graph(nodes, connections)
        GraphResolver.call(nodes, connections)
      end

      def infer(value)
        return {} unless value.is_a?(Hash) && value.present?

        infer_value(value)
      end

      def expression_value?(value)
        value.is_a?(String) && value.start_with?("=")
      end

      # :indeterminate means a rule is anchored to an expression-valued parameter,
      # so the target must neither be dropped nor have its requirements enforced.
      def display_state(display_options, configuration)
        display_options = normalize_options(display_options)
        show_rules = display_options["show"]
        hide_rules = display_options["hide"]
        return :visible if show_rules.blank? && hide_rules.blank?

        configuration = normalize_configuration(configuration)
        indeterminate = false

        if show_rules.present?
          outcome = rules_outcome(show_rules, configuration)
          return :hidden if outcome == false
          indeterminate ||= outcome == :unknown
        end

        if hide_rules.present?
          outcome = rules_outcome(hide_rules, configuration)
          return :hidden if outcome == true
          indeterminate ||= outcome == :unknown
        end

        indeterminate ? :indeterminate : :visible
      end

      def visible?(display_options, configuration)
        display_state(display_options, configuration) != :hidden
      end

      def definitely_visible?(display_options, configuration)
        display_state(display_options, configuration) == :visible
      end

      private

      def stringify(schema)
        schema.respond_to?(:to_h) ? schema.to_h.deep_stringify_keys : {}
      end

      def overlay(input_schema, declared_schema)
        return declared_schema if input_schema.empty?
        return input_schema if declared_schema.empty?

        if any_of_wrapper?(input_schema)
          return(
            union(
              *input_schema["anyOf"].map { |branch| overlay(stringify(branch), declared_schema) },
            )
          )
        end

        merged = input_schema.merge(declared_schema)
        return merged unless object_schema?(input_schema) && object_schema?(declared_schema)

        merged["properties"] = (input_schema["properties"] || {}).merge(
          declared_schema["properties"] || {},
        )

        required = Array(input_schema["required"]) | Array(declared_schema["required"])
        required.empty? ? merged.delete("required") : merged["required"] = required
        merged
      end

      def merge_pair(left, right)
        merged = left.merge(right)
        return merged unless object_schema?(left) && object_schema?(right)

        merged["properties"] = (left["properties"] || {}).merge(
          right["properties"] || {},
        ) do |_name, left_value, right_value|
          if object_schema?(left_value) && object_schema?(right_value)
            merge_pair(left_value, right_value)
          else
            right_value
          end
        end

        required = Array(left["required"]) | Array(right["required"])
        required.empty? ? merged.delete("required") : merged["required"] = required
        merged
      end

      def object_schema?(schema)
        schema.is_a?(Hash) && Array(schema["type"]).include?("object")
      end

      def union_branches(schema)
        any_of_wrapper?(schema) ? schema["anyOf"] : [schema]
      end

      def any_of_wrapper?(schema)
        (schema.keys - ["$schema"]) == ["anyOf"]
      end

      def infer_value(value)
        case value
        when Hash
          {
            "type" => "object",
            "properties" =>
              value.to_h.transform_keys(&:to_s).transform_values { |child| infer_value(child) },
          }
        when Array
          item_schemas = value.map { |child| infer_value(child) }.uniq
          schema = { "type" => "array" }
          if item_schemas.any?
            schema["items"] = item_schemas.one? ? item_schemas.first : { "anyOf" => item_schemas }
          end
          schema
        when Integer
          { "type" => "integer" }
        when Numeric
          { "type" => "number" }
        when TrueClass, FalseClass
          { "type" => "boolean" }
        when NilClass
          { "type" => "null" }
        else
          { "type" => "string" }
        end
      end

      def normalize_options(options)
        return {} if options.blank?

        options.to_h.deep_stringify_keys
      end

      # Rules only anchor on top-level keys, so a shallow pass avoids deep-copying
      # the whole configuration on every visibility check.
      def normalize_configuration(configuration)
        return {} if configuration.blank?

        configuration.to_h.stringify_keys
      end

      def rules_outcome(rules, configuration)
        unknown = false

        rules.each do |field_name, expected|
          value = configuration[field_name.to_s]
          if expression_value?(value)
            unknown = true
            next
          end

          return false unless matches_rule?(expected, value)
        end

        unknown ? :unknown : true
      end

      def matches_rule?(expected, value)
        conditions = expected.is_a?(Array) ? expected : [expected]
        conditions.any? { |condition| matches_condition?(condition, value) }
      end

      def matches_condition?(condition, value)
        operator = condition.is_a?(Hash) ? condition["condition"] : nil
        if operator.blank?
          return value.include?(condition) if value.is_a?(Array) && !condition.is_a?(Array)
          return condition == value
        end
        return value != operator["not"] if operator.key?("not")

        if operator.key?("exists")
          return operator["exists"] ? !empty_value?(value) : empty_value?(value)
        end

        false
      end

      def empty_value?(value)
        return true if value.nil? || value == ""
        return value.empty? if value.is_a?(Array)

        false
      end
    end
  end
end
