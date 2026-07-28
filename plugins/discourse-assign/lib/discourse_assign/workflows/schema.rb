# frozen_string_literal: true

module DiscourseAssign
  module Workflows
    module Schema
      ASSIGNEE_SCHEMA = {
        "type" => "object",
        "properties" => {
          "type" => {
            "type" => %w[string null],
          },
          "user" => {
            "type" => "object",
            "properties" => DiscourseWorkflows::Schema::BASIC_USER_PROPERTIES,
          },
          "group" => {
            "type" => "object",
            "properties" => DiscourseWorkflows::Schema::BASIC_GROUP_PROPERTIES,
          },
        },
      }.freeze

      ASSIGN_TOPIC_OUTPUT_SCHEMA = {
        "$schema" => DiscourseWorkflows::Schema::DRAFT_URI,
        "type" => "object",
        "properties" => {
          "assignee" => ASSIGNEE_SCHEMA,
          "previously_assigned" => ASSIGNEE_SCHEMA,
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
              "assigned_to" => ASSIGNEE_SCHEMA,
              "assigned_by_user" => {
                "type" => "object",
                "properties" => DiscourseWorkflows::Schema::BASIC_USER_PROPERTIES,
              },
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

      ASSIGNED_OUTPUT_SCHEMA =
        DiscourseWorkflows::Schema.merge(
          DiscourseWorkflows::Schema::POST_SCHEMA,
          DiscourseWorkflows::Schema::TOPIC_LIST_ITEM_SCHEMA,
          ASSIGNMENT_SCHEMA,
        ).freeze
    end
  end
end
