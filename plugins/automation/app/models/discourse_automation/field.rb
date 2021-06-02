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

      automation.triggerable && automation.triggerable.on_update.call(
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
      'category' => {
        'category_id' => {
          'type' => ['string', 'integer', 'null']
        }
      },
      'user' => {
        'username' => {
          'type' => 'string'
        }
      },
      'text' => {
        'text' => {
          'type' => ['string', 'integer']
        }
      },
      'text_list' => {
        'list' => {
          'type' => 'array',
          'items' => [{ 'type': 'string' }]
        }
      },
      'date' => {
        'execute_at' => {
          'type' => 'integer'
        }
      },
      'group' => {
        'group_id' => {
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
