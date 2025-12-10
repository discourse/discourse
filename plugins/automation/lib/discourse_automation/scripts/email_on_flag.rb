# frozen_string_literal: true

DiscourseAutomation::Scriptable.add("email_on_flag") do
  version 1
  run_in_background

  triggerables [DiscourseAutomation::Triggers::FLAG_CREATED]

  field :email_template,
        component: :message,
        required: true,
        accepts_placeholders: true,
        default_value: I18n.t("discourse_automation.scriptables.email_on_flag.default_template")

  field :recipients, component: :email_group_user, required: true

  script do |context, fields, automation|
    post_action = context["post_action"]
    post = post_action&.post
    flagger = post_action&.user
    target_user = post&.user
    max_excerpt_length = 300

    placeholders = {
      topic_url: "#{Discourse.base_url}#{post&.topic&.relative_url}",
      post_url: "#{Discourse.base_url}#{post&.url}",
      topic_title: post&.topic&.title,
      post_number: post&.post_number,
      flagger_username: flagger&.username,
      flagged_username: target_user&.username,
      flag_type: PostActionTypeView.new.names[post_action&.post_action_type_id],
      category: post&.topic&.category&.name,
      tags: post&.topic&.tags&.map(&:name)&.join(", "),
      site_title: SiteSetting.title,
      post_excerpt: post&.excerpt(max_excerpt_length, strip_links: true),
    }.compact

    raw_template = fields.dig("email_template", "value")
    body = DiscourseAutomation::Scriptable::Utils.apply_placeholders(raw_template, placeholders)

    recipients = Array(fields.dig("recipients", "value")).uniq

    if recipients.blank?
      Rails.logger.warn "[discourse-automation] Email on flag skipped - no recipients configured"
      next
    end

    to_emails = recipients.select { |r| r.include?("@") }
    to_users = recipients - to_emails

    if to_users.present?
      primary_emails =
        User
          .where(username: to_users)
          .map(&:primary_email)
          .compact
          .map(&:email)
          .select { |email| Email.is_valid?(email) }
      to_emails.concat(primary_emails)
    end

    to_emails.select! { |email| Email.is_valid?(email) }
    to_emails.uniq!

    if to_emails.empty?
      Rails.logger.warn "[discourse-automation] Email on flag skipped - no valid email recipients"
      next
    end

    subject =
      I18n.t(
        "discourse_automation.scriptables.email_on_flag.subject",
        topic_title: placeholders[:topic_title] || "",
        flagger_username: placeholders[:flagger_username] || "",
      )

    to_emails.each do |email|
      begin
        DiscourseAutomation::FlagMailer.send_flag_email(
          email,
          subject: subject,
          body: body,
        ).deliver_now
      rescue => e
        Rails.logger.warn "[discourse-automation] Failed to send email for automation #{automation.id}: #{e.message}"
      end
    end
  end
end
