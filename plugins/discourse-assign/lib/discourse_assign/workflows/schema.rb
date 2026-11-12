# frozen_string_literal: true

module DiscourseAssign
  module Workflows
    module Schema
      ASSIGN_TOPIC_OUTPUT_SCHEMA = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "assignee" => DiscourseWorkflows::Schema::ASSIGNEE_PROPERTIES.merge("x-optional" => true),
          "previously_assigned" => DiscourseWorkflows::Schema::ASSIGNEE_PROPERTIES,
        },
      }.freeze

      CHECK_ASSIGNMENT_OUTPUT_SCHEMA = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "is_assigned" => {
            "type" => "boolean",
          },
        },
      }.freeze

      ASSIGNMENT_SCHEMA = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "assignment" => {
            "type" => "object",
            "properties" => {
              "id" => {
                "type" => "integer",
              },
              "target_type" => {
                "type" => "string",
              },
              "target_id" => {
                "type" => "integer",
              },
              "topic_id" => {
                "type" => "integer",
              },
              "topic_assignment" => {
                "type" => "boolean",
              },
              "assigned_to_id" => {
                "type" => "integer",
              },
              "assigned_to_type" => {
                "type" => "string",
              },
              "assigned_to" => DiscourseWorkflows::Schema::ASSIGNEE_PROPERTIES,
              "assigned_by_user" =>
                DiscourseWorkflows::Schema.nullable_user("User who made the assignment"),
              "note" => {
                "type" => %w[string null],
              },
              "status" => {
                "type" => %w[string null],
              },
            },
          },
        },
      }.freeze

      ASSIGNMENT_OUTPUT_SCHEMA =
        DiscourseWorkflows::Schema.merge(
          DiscourseWorkflows::Schema::POST_SCHEMA,
          DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
          ASSIGNMENT_SCHEMA,
          DiscourseWorkflows::Schema::ACTOR_SCHEMA,
        ).freeze

      ASSIGNMENT_V2_SCHEMA =
        DiscourseWorkflows::Schema.document(
          "assignment" => {
            "type" => "object",
            "properties" =>
              ASSIGNMENT_SCHEMA.dig("properties", "assignment", "properties").transform_keys(
                "assigned_by_user" => "assigned_by",
              ),
          },
        )

      ASSIGNMENT_V2_OUTPUT_SCHEMA =
        DiscourseWorkflows::Schema.merge(
          DiscourseWorkflows::Schema::POST_SCHEMA,
          DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
          ASSIGNMENT_V2_SCHEMA,
          DiscourseWorkflows::Schema::ACTOR_SCHEMA,
        ).freeze
    end
  end
end
