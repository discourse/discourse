# frozen_string_literal: true

DiscourseAutomation::Scriptable::ZAPIER_WEBHOOK = "zapier_webhook"

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scriptable::ZAPIER_WEBHOOK) do
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
      :discourse_automation_call_zapier_webhook,
      webhook_url: webhook_url,
      context: context,
    )
  end
end
