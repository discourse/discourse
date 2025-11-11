# frozen_string_literal: true

module DiscoursePolicy::UserOptionExtension
  def self.prepended(base)
    def base.policy_email_frequencies
      @policy_email_frequencies ||= { never: 0, when_away: 1, always: 2 }
    end

    base.enum :policy_email_frequency, base.policy_email_frequencies, prefix: "send_policy_email"
  end
end
