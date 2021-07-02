# frozen_string_literal: true

module DiscourseAutomation
  class Field < ActiveRecord::Base
    self.table_name = 'discourse_automation_fields'

    belongs_to :automation, class_name: 'DiscourseAutomation::Automation'

    around_save :on_update_callback

    def on_update_callback
      previous_fields = automation.serialized_fields

      automation.reset!

      yield

      automation&.triggerable&.on_update&.call(
        automation,
        automation.serialized_fields,
        previous_fields
      )
    end

    validate :metadata_schema
    def metadata_schema
      targetable = (target == 'trigger' ? automation.triggerable : automation.scriptable)
      if !(targetable.components.include?(component.to_sym))
        errors.add(
          :base,
          I18n.t(
            'discourse_automation.models.fields.invalid_field',
            component: component,
            target: target,
            target_name: targetable.name
          )
        )
      else
        schema = SCHEMAS[component]
        if !schema || !JSONSchemer.schema('type' => 'object', 'properties' => schema).valid?(metadata)
          errors.add(:base, I18n.t('discourse_automation.models.fields.invalid_metadata', component: component, field: name))
        end
      end
    end

    SCHEMAS = {
      'choices' => {
        'value' => {
          'type' => ['string', 'integer']
        }
      },
      'tags' => {
        'value' => {
          'type' => 'array',
          'items' => [{ 'type': 'string' }]
        }
      },
      'category' => {
        'value' => {
          'type' => ['string', 'integer', 'null']
        }
      },
      'user' => {
        'value' => {
          'type' => 'string'
        }
      },
      'text' => {
        'value' => {
          'type' => ['string', 'integer']
        }
      },
      'boolean' => {
        'value' => {
          'type' => ['boolean']
        }
      },
      'text_list' => {
        'value' => {
          'type' => 'array',
          'items' => [{ 'type': 'string' }]
        }
      },
      'date_time' => {
        'value' => {
          'type' => 'string'
        }
      },
      'group' => {
        'value' => {
          'type' => 'integer'
        }
      },
      'pms' => {
        'type': 'array',
        'items': [
          {
            'type': 'object',
            'properties': {
              'raw' => { 'type' => 'string' },
              'title' => { 'type' => 'string' },
              'delay' => { 'type' => 'integer' },
              'encrypt' => { 'type' => 'boolean' }
            }
          }
        ]
      }
    }
  end
end
