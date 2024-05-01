# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::ZAPIER_WEBHOOK) do
  field :webhook_url, component: :text, required: true

  version 1

  triggerables %i[user_promoted user_added_to_group user_badge_granted user_removed_from_group]

  script do |context, fields|
    webhook_url = fields.dig("webhook_url", "value")

    unless webhook_url&.start_with?("https://hooks.zapier.com/hooks/catch/")
      Rails.logger.warn "[discourse-automation] #{webhook_url} is not a valid Zapier webhook URL, expecting an URL starting with https://hooks.zapier.com/hooks/catch/"
      next
    end

    Jobs.enqueue(
      Jobs::DiscourseAutomation::CallZapierWebhook,
      webhook_url: webhook_url,
      context: context,
    )
  end
end
