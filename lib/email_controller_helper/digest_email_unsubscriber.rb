# frozen_string_literal: true

module EmailControllerHelper
  class DigestEmailUnsubscriber < BaseEmailUnsubscriber
    def prepare_unsubscribe_options(controller)
      super(controller)
      controller.instance_variable_set(:@digest_unsubscribe, !SiteSetting.disable_digest_emails)

      frequency_in_minutes = key_owner.user_option.digest_after_minutes
      email_digests = key_owner.user_option.email_digests
      frequencies = DigestEmailSiteSetting.values.dup
      never = frequencies.delete_at(0)
      allowed_frequencies = %w[never weekly every_month every_six_months]

      result =
        frequencies.reduce(
          frequencies: [],
          current: nil,
          selected: nil,
          take_next: false,
        ) do |memo, v|
          memo[:current] = v[:name] if v[:value] == frequency_in_minutes && email_digests
          next(memo) if allowed_frequencies.exclude?(v[:name])

          memo.tap do |m|
            m[:selected] = v[:value] if m[:take_next] && email_digests
            m[:frequencies] << [I18n.t("unsubscribe.digest_frequency.#{v[:name]}"), v[:value]]
            m[:take_next] = !m[:take_next] && m[:current]
          end
        end

      digest_frequencies =
        result
          .slice(:frequencies, :current, :selected)
          .tap do |r|
            r[:frequencies] << [
              I18n.t("unsubscribe.digest_frequency.#{never[:name]}"),
              never[:value],
            ]
            r[:selected] ||= never[:value]
            r[:current] ||= never[:name]
          end

      controller.instance_variable_set(:@digest_frequencies, digest_frequencies)
    end

    def unsubscribe(params)
      updated = super(params)

      if params[:digest_after_minutes]
        digest_frequency = params[:digest_after_minutes].to_i

        unsubscribe_key.user.user_option.update_columns(
          digest_after_minutes: digest_frequency,
          email_digests: digest_frequency.positive?,
        )
        updated = true
      end

      updated
    end
  end
end
