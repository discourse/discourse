# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::EMAIL_ON_FLAGGED_POST) do
  version 1
  run_in_background if !Rails.env.test?

  triggerables [DiscourseAutomation::Triggers::POST_FLAG_CREATED]

  field :email_template,
        component: :message,
        required: true,
        accepts_placeholders: true,
        default_value:
          I18n.t("discourse_automation.scriptables.email_on_flagged_post.default_template")

  field :recipients, component: :users, required: true

  script do |context, fields, automation|
    recipients = fields.dig("recipients", "value").uniq
    next if recipients.blank?

    to_emails = []
    to_emails = to_emails.concat(recipients.select { |r| r.include?("@") })
    to_users = recipients - to_emails

    if to_users.present?
      primary_emails = User.includes(:primary_email).filter_by_username(to_users).map(&:email)
      to_emails.concat(primary_emails)
    end

    to_emails.select! { |email| Email.is_valid?(email) }
    to_emails.uniq!

    automation_email_template_field_id = automation.fields.where(name: "email_template").pick(:id)

    to_emails.each do |email|
      Jobs.enqueue(
        Jobs::DiscourseAutomation::SendFlagEmail,
        email:,
        email_template_automation_field_id: automation_email_template_field_id,
        post_action_id: context["post_action_id"],
      )
    end
  end
end
