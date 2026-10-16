# frozen_string_literal: true

class DsaNotification
  def self.supports?(reviewable, action_id)
    reviewable.is_a?(ReviewableFlaggedPost) &&
      %w[agree_and_hide delete_and_agree agree_and_suspend agree_and_silence].include?(
        action_id.to_s,
      )
  end

  def self.context(reviewable:, action_id:, args:, automated_detection:, automated_decision:)
    if SiteSetting.contact_email.blank? && SiteSetting.contact_url.blank?
      raise Discourse::InvalidParameters.new(I18n.t("dsa_notifications.contact_required"))
    end

    post = reviewable.target || Post.with_deleted.find(reviewable.target_id)
    rule = args.fetch(:dsa_classification).fetch(:community_rule)
    penalty_until = nil
    if action_id.to_s.in?(%w[agree_and_suspend agree_and_silence])
      penalty_until = Time.zone.parse((args[:suspend_until] || args[:silenced_till]).to_s)
      raise Discourse::InvalidParameters.new(:penalty_until) unless penalty_until&.future?
    end

    {
      "post_url" => post.full_url,
      "post_user_id" => post.user_id,
      "topic_title" => post.topic.title,
      "post_number" => post.post_number,
      "ground" => rule.fetch("ground"),
      "explanation" => rule.fetch("explanation"),
      "source" =>
        (
          if reviewable.reviewable_scores.where.not(user_id: Discourse::SYSTEM_USER_ID).exists?
            "flag"
          else
            "review"
          end
        ),
      "automated_detection" => automated_detection == "Yes",
      "automated_decision" => automated_decision,
      "contact" => SiteSetting.contact_email.presence || SiteSetting.contact_url,
      "contact_email" => SiteSetting.contact_email.present?,
      "penalty_until" => penalty_until&.iso8601,
      "post_action" => args[:post_action].presence || "none",
    }
  rescue ArgumentError, TypeError
    raise Discourse::InvalidParameters.new(:penalty_until)
  end

  def self.append(body, context, template:, recipient:)
    return body unless context

    locale = recipient.effective_locale
    account_notice =
      template.start_with?("user_notifications.account_") ||
        template == "system_messages.silenced_by_staff"
    primary_recipient = context.fetch("post_user_id") == recipient.id
    return body unless account_notice || primary_recipient

    details = []
    if account_notice && primary_recipient
      details << I18n.t(
        "dsa_notifications.post_reference_#{context.fetch("source")}",
        locale:,
        title: context.fetch("topic_title"),
        number: context.fetch("post_number"),
        url: context.fetch("post_url"),
      )
      if %w[edit delete_all].include?(context.fetch("post_action"))
        details << I18n.t("dsa_notifications.post_actions.#{context.fetch("post_action")}", locale:)
      end
    end
    contact = context.fetch("contact")
    contact_url = context.fetch("contact_email") ? "mailto:#{contact}" : contact
    contact_link = "[#{I18n.t("dsa_notifications.contact", locale:)}](#{contact_url})"
    provenance = []
    if !account_notice &&
         (
           context.fetch("source") == "review" ||
             TranslationOverride.exists?(locale:, translation_key: "#{template}.text_body_template")
         )
      provenance << I18n.t("dsa_notifications.source_#{context.fetch("source")}", locale:)
    end
    if context.fetch("automated_detection")
      provenance << I18n.t("dsa_notifications.detection_automated", locale:)
    end
    if context.fetch("automated_decision") != "AUTOMATED_DECISION_NOT_AUTOMATED"
      provenance << I18n.t(
        "dsa_notifications.decisions_automation.#{context.fetch("automated_decision")}",
        locale:,
      )
    end
    details << provenance.join(" ") if provenance.present?
    details << I18n.t(
      "dsa_notifications.statement",
      locale:,
      ground: context.fetch("ground"),
      explanation: context.fetch("explanation"),
      contact: contact_link,
    )
    "#{body.rstrip}\n\n#{details.join("\n\n")}".rstrip
  end
end
