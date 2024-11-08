# frozen_string_literal: true

module DiscourseAutomation
  class Field < ActiveRecord::Base
    self.table_name = "discourse_automation_fields"

    belongs_to :automation, class_name: "DiscourseAutomation::Automation"

    around_save :on_update_callback

    def on_update_callback
      previous_fields = automation.serialized_fields

      automation.reset!

      yield

      automation&.triggerable&.on_update&.call(
        automation,
        automation.serialized_fields,
        previous_fields,
      )
    end

    validate :required_field
    def required_field
      if template && template[:required] && metadata && metadata["value"].blank?
        raise_required_field(name, target, targetable)
      end
    end

    validate :validator
    def validator
      if template && template[:validator]
        error = template[:validator].call(metadata["value"])
        errors.add(:base, error) if error
      end
    end

    def targetable
      target == "trigger" ? automation.triggerable : automation.scriptable
    end

    def template
      targetable&.fields&.find do |tf|
        targetable.id == target && tf[:name].to_s == name && tf[:component].to_s == component
      end
    end

    validate :metadata_schema
    def metadata_schema
      if !(targetable.components.include?(component.to_sym))
        errors.add(
          :base,
          I18n.t(
            "discourse_automation.models.fields.invalid_field",
            component: component,
            target: target,
            target_name: targetable.name,
          ),
        )
      else
        schema = SCHEMAS[component]
        if !schema ||
             !JSONSchemer.schema({ "type" => "object", "properties" => schema }).valid?(metadata)
          errors.add(
            :base,
            I18n.t(
              "discourse_automation.models.fields.invalid_metadata",
              component: component,
              field: name,
            ),
          )
        end
      end
    end

    SCHEMAS = {
      "key-value" => {
        "type" => "array",
        "uniqueItems" => true,
        "items" => {
          "type" => "object",
          "title" => "group",
          "properties" => {
            "key" => {
              "type" => "string",
            },
            "value" => {
              "type" => "string",
            },
          },
        },
      },
      "choices" => {
        "value" => {
          "type" => %w[string integer null],
        },
      },
      "tags" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "string" }],
        },
      },
      "trust-levels" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "integer" }],
        },
      },
      "categories" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "string" }],
        },
      },
      "category" => {
        "value" => {
          "type" => %w[string integer null],
        },
      },
      "category_notification_level" => {
        "value" => {
          "type" => "integer",
        },
      },
      "custom_field" => {
        "value" => {
          "type" => "integer",
        },
      },
      "custom_fields" => {
        "value" => {
          "type" => [{ type: "string" }],
        },
      },
      "user" => {
        "value" => {
          "type" => "string",
        },
      },
      "user_profile" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "string" }],
        },
      },
      "users" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "string" }],
        },
      },
      "text" => {
        "value" => {
          "type" => %w[string integer null],
        },
      },
      "post" => {
        "value" => {
          "type" => %w[string integer null],
        },
      },
      "message" => {
        "value" => {
          "type" => %w[string integer null],
        },
      },
      "boolean" => {
        "value" => {
          "type" => ["boolean"],
        },
      },
      "text_list" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "string" }],
        },
      },
      "date_time" => {
        "value" => {
          "type" => "string",
        },
      },
      "group" => {
        "value" => {
          "type" => "integer",
        },
      },
      "groups" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "integer" }],
        },
      },
      "email_group_user" => {
        "value" => {
          "type" => "array",
          "items" => [{ type: "string" }],
        },
      },
      "pms" => {
        type: "array",
        items: [
          {
            type: "object",
            properties: {
              "raw" => {
                "type" => "string",
              },
              "title" => {
                "type" => "string",
              },
              "delay" => {
                "type" => "integer",
              },
              "prefers_encrypt" => {
                "type" => "boolean",
              },
            },
          },
        ],
      },
      "period" => {
        "type" => "object",
        "properties" => {
          "interval" => {
            "type" => "integer",
          },
          "frequency" => {
            "type" => "string",
          },
        },
      },
    }.freeze

    private

    def raise_required_field(name, target, targetable)
      errors.add(
        :base,
        I18n.t(
          "discourse_automation.models.fields.required_field",
          name: name,
          target: target,
          target_name: targetable.name,
        ),
      )
    end
  end
end
