# frozen_string_literal: true

module DiscourseWorkflows
  module WorkflowTimezone
    module_function

    DEFAULT = "UTC"

    def default
      timezone = Time.zone&.tzinfo&.name.presence
      timezone == "Etc/UTC" ? DEFAULT : (timezone || DEFAULT)
    end

    def for(workflow:, workflow_version: nil)
      timezone =
        workflow_version&.settings&.dig("timezone").presence ||
          workflow&.settings&.dig("timezone").presence || default

      valid?(timezone) ? timezone : default
    end

    def valid?(timezone)
      return false if timezone.blank?

      TZInfo::Timezone.get(timezone)
      true
    rescue TZInfo::InvalidTimezoneIdentifier
      false
    end
  end
end
