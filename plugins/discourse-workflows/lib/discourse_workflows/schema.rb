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

    TOPIC_PROPERTIES = JSON.parse(<<~JSON).freeze
      {
        "id": { "type": "integer" },
        "title": { "type": "string" },
        "fancy_title": { "type": "string" },
        "slug": { "type": "string" },
        "posts_count": { "type": "integer" },
        "category_id": { "type": ["integer", "null"] },
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
        "staff": { "type": "boolean" }
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
    WEBHOOK_POST_SCHEMA =
      entity(
        "post",
        POST_PROPERTIES.except(
          "category_name",
          "excerpt",
          "like_count",
          "tags",
          "upload_ids",
        ).merge("category_slug" => { "type" => "string" }),
        "WebHookPostSerializer payload",
      )
    BASIC_USER_SCHEMA = entity("user", BASIC_USER_PROPERTIES, "BasicUserSerializer payload")
    USER_SCHEMA = entity("user", USER_PROPERTIES, "Basic safe user attributes")
    USER_ACTION_SCHEMA =
      entity(
        "user",
        USER_PROPERTIES.merge(JSON.parse(<<~JSON)),
          {
            "title": { "type": ["string", "null"] },
            "bio_raw": { "type": ["string", "null"] },
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
        "Discourse user lookup/update payload",
      )
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

      def union(*schemas)
        schemas = schemas.flatten.map { |schema| stringify(schema) }
        return {} if schemas.empty? || schemas.any?(&:empty?)

        branches = schemas.flat_map { |schema| union_branches(schema) }.uniq
        return branches.first if branches.one?

        { "$schema" => DRAFT_URI, "anyOf" => branches }
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

      def visible?(display_options, configuration)
        display_options = normalize_options(display_options)
        configuration = normalize_options(configuration)
        show_rules = display_options["show"]
        hide_rules = display_options["hide"]

        return false if show_rules.present? && !matches_rules?(show_rules, configuration)
        return false if hide_rules.present? && matches_rules?(hide_rules, configuration)

        true
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

      def matches_rules?(rules, configuration)
        rules.all? do |field_name, expected|
          matches_rule?(expected, configuration[field_name.to_s])
        end
      end

      def matches_rule?(expected, value)
        conditions = expected.is_a?(Array) ? expected : [expected]
        conditions.any? { |condition| matches_condition?(condition, value) }
      end

      def matches_condition?(condition, value)
        operator = condition.is_a?(Hash) ? condition["condition"] : nil
        return condition == value if operator.blank?
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
