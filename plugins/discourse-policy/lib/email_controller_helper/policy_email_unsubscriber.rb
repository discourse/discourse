# frozen_string_literal: true

module EmailControllerHelper
  class PolicyEmailUnsubscriber < BaseEmailUnsubscriber
    def prepare_unsubscribe_options(controller)
      super(controller)

      policy_email_frequencies =
        UserOption.policy_email_frequencies.map do |(freq, _)|
          [I18n.t("unsubscribe.policy_emails.#{freq}"), freq]
        end

      controller.instance_variable_set(:@policy_email_frequencies, policy_email_frequencies)
      controller.instance_variable_set(
        :@current_policy_email_frequency,
        key_owner.user_option.policy_email_frequency,
      )
    end

    def unsubscribe(params)
      updated = super(params)

      if params[:policy_email_frequency]
        key_owner.user_option.update!(policy_email_frequency: params[:policy_email_frequency])
        updated = true
      end

      updated
    end
  end
end
