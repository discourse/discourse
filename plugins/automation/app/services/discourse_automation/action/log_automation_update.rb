# frozen_string_literal: true

module DiscourseAutomation
  module Action
    # Logs changes made to an automation to the staff action log.
    # Compares the current state of the automation with its previous state
    # and logs any differences found in attributes or fields.
    class LogAutomationUpdate < Service::ActionBase
      # @param [DiscourseAutomation::Automation] automation The automation after updates
      # @param [Hash] previous_state The state of the automation before updates
      # @param [Guardian] guardian The guardian for the current user
      param :automation
      param :previous_state
      param :guardian

      def call
        return if changes.empty?

        StaffActionLogger.new(guardian.user).log_custom("update_automation", **details)
      end

      private

      def changes
        @changes ||= attribute_changes.merge(field_changes)
      end

      def details
        { id: automation.id, name: automation.name }.merge(changes)
      end

      def attribute_changes
        %i[name script trigger enabled]
          .index_with { |attr| [previous_state[attr], automation.public_send(attr)] }
          .reject { |_, (prev, curr)| prev == curr }
          .transform_values { |(prev, curr)| "#{format_value(prev)} → #{format_value(curr)}" }
      end

      def field_changes
        current_fields = automation.serialized_fields
        previous_fields = previous_state[:fields]

        (current_fields.keys | previous_fields.keys)
          .sort
          .index_with { |name| [previous_fields[name], current_fields[name]] }
          .reject { |_, (prev, curr)| prev == curr || (field_empty?(prev) && field_empty?(curr)) }
          .transform_values do |(prev, curr)|
            "#{format_field_value(prev)} → #{format_field_value(curr)}"
          end
      end

      def format_value(value)
        value.to_s.presence || empty_value
      end

      def field_empty?(field)
        return true if field.blank?
        value = field["value"]
        !value.in?([true, false]) && value.blank?
      end

      def format_field_value(field)
        field_empty?(field) ? empty_value : field["value"].to_s
      end

      def empty_value
        @empty_value ||= I18n.t("discourse_automation.staff_action_logs.empty_value")
      end
    end
  end
end
