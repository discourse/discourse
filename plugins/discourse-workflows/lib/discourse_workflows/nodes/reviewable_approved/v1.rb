# frozen_string_literal: true

module DiscourseWorkflows
  module Nodes
    module ReviewableApproved
      class V1 < NodeType
        OUTPUT_SCHEMA = {
          "$schema" => Schema::DRAFT_URI,
          "type" => "object",
          "properties" => {
            "reviewable" => {
              "type" => "object",
              "properties" => {
                "id" => {
                  "type" => "integer",
                },
                "type" => {
                  "type" => "string",
                },
                "status" => {
                  "type" => "string",
                },
                "target_type" => {
                  "type" => %w[string null],
                },
                "target_id" => {
                  "type" => %w[integer null],
                },
                "topic_id" => {
                  "type" => %w[integer null],
                },
                "category_id" => {
                  "type" => %w[integer null],
                },
                "score" => {
                  "type" => "number",
                },
                "created_at" => {
                  "type" => %w[string null],
                  "format" => "date-time",
                },
              },
            },
          },
        }.freeze

        description(
          name: "trigger:reviewable_approved",
          version: "1.0",
          defaults: {
            icon: "user-check",
            color: "green",
          },
          group: "discourse_triggers",
          events: [:reviewable_transitioned_to],
          output_contracts: [{ schema: OUTPUT_SCHEMA }],
          properties: -> do
            {
              reviewable_types: {
                type: :multi_options,
                required: false,
                options:
                  reviewable_type_options.map do |option|
                    { value: option[:id], label: option[:name] }
                  end,
              },
            }
          end,
        )

        def self.load_options_context(context)
          case context.method_name
          when "reviewable_types"
            reviewable_type_options.select { |option| context.matches_filter?(option[:name]) }
          end
        end

        def self.reviewable_type_options
          Reviewable
            .types
            .uniq(&:sti_name)
            .sort_by(&:name)
            .map { |klass| { id: klass.sti_name, name: klass.name.demodulize.underscore.humanize } }
        end

        class << self
          private :reviewable_type_options
        end

        def initialize(status, reviewable)
          super(parameters: {})
          @status = status
          @reviewable = reviewable
        end

        def valid?
          @status.to_s == "approved" && @reviewable.present?
        end

        def output
          { reviewable: reviewable_data(@reviewable) }
        end

        def matches?(trigger_ctx)
          reviewable_types =
            Array.wrap(trigger_ctx.get_node_parameter("reviewable_types")).compact_blank

          reviewable_types.empty? || reviewable_types.include?(@reviewable.class.sti_name)
        end

        private

        def reviewable_data(reviewable)
          {
            id: reviewable.id,
            type: reviewable.type,
            status: reviewable.status,
            target_type: reviewable.target_type,
            target_id: reviewable.target_id,
            topic_id: reviewable.topic_id,
            category_id: reviewable.category_id,
            score: reviewable.score,
            created_at: reviewable.created_at&.iso8601,
          }
        end
      end
    end
  end
end
