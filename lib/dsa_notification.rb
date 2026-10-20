# frozen_string_literal: true

class DsaNotification
  ACTIONS = {
    "ReviewableFlaggedPost" => {
      "agree_and_hide" => nil,
      "delete_and_agree" => nil,
      "delete_and_ignore" => nil,
      "delete_and_agree_replies" => nil,
      "delete_and_ignore_replies" => nil,
      "agree_and_suspend" => nil,
      "agree_and_silence" => nil,
      "delete_user" => nil,
      "delete_user_block" => nil,
      "delete_and_block_user" => nil,
      "agree_and_edit" => "post_edited",
      "agree_and_keep_hidden" => "post_kept_hidden",
      "agree_and_keep_deleted" => "post_kept_deleted",
    },
    "ReviewableQueuedPost" => {
      "reject_post" => "submission_rejected",
      "discard_post" => "submission_rejected",
      "revise_and_reject_post" => nil,
      "reject_and_suspend" => "submission_rejected",
      "reject_and_silence" => "submission_rejected",
      "delete_user" => nil,
      "delete_user_block" => nil,
      "delete_and_block_user" => nil,
    },
    "ReviewablePost" => {
      "reject_and_delete" => nil,
      "reject_and_keep_deleted" => "post_kept_deleted",
      "reject_and_suspend" => nil,
      "reject_and_silence" => nil,
    },
    "ReviewableUser" => {
      "delete_user" => nil,
      "delete_user_block" => nil,
      "suspend_user" => nil,
      "silence_user" => nil,
      "remove_avatar" => "avatar_removed",
    },
  }.freeze
  private_constant :ACTIONS

  def self.supports?(reviewable, action_id)
    return false if reviewable.is_a?(ReviewableUser) && reviewable.registration_review?

    !reviewable.potentially_illegal? && ACTIONS.fetch(reviewable.type, {}).key?(action_id.to_s)
  end

  def self.context(reviewable:, action_id:, args:, automated_detection:, automated_decision:)
    if SiteSetting.contact_email.blank? && SiteSetting.contact_url.blank?
      raise Discourse::InvalidParameters.new(I18n.t("dsa_notifications.contact_required"))
    end

    user = reviewable.target_user
    raise Discourse::InvalidParameters.new(:user) unless user

    post =
      if reviewable.target_type == "Post"
        reviewable.target || Post.with_deleted.find(reviewable.target_id)
      end
    rule = args.fetch(:dsa_classification).fetch(:community_rule)
    penalty_until = nil
    if action_id.to_s.in?(
         %w[
           agree_and_suspend
           agree_and_silence
           reject_and_suspend
           reject_and_silence
           suspend_user
           silence_user
         ],
       )
      penalty_field = action_id.to_s.include?("suspend") ? :suspend_until : :silenced_till
      penalty_until = Time.zone.parse(args[penalty_field].to_s)
      raise Discourse::InvalidParameters.new(:penalty_until) unless penalty_until&.future?
    end
    kind =
      if post
        "post"
      elsif reviewable.is_a?(ReviewableQueuedPost)
        "submission"
      elsif action_id.to_s == "remove_avatar"
        "avatar"
      else
        "account"
      end

    {
      "post_url" => post&.full_url,
      "post_user_id" => user.id,
      "topic_title" =>
        post&.topic&.title || reviewable.payload&.dig("title") || reviewable.topic&.title,
      "post_number" => post&.post_number,
      "content_kind" => kind,
      "recipient_email" => user.email,
      "recipient_locale" => user.effective_locale,
      "score_type" => reviewable.reviewable_scores.first&.reviewable_score_type,
      "notice" => ACTIONS.dig(reviewable.type, action_id.to_s),
      "ground" => rule.fetch("ground"),
      "explanation" => rule.fetch("explanation"),
      "source" =>
        (
          if reviewable
               .reviewable_scores
               .where.not(user_id: Discourse::SYSTEM_USER_ID)
               .where(reviewable_score_type: PostActionType.notify_flag_type_ids)
               .exists?
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

  def self.deliver_fallback(reviewable:, context:)
    return unless context&.fetch("notice")

    recipient = reviewable.target_user
    SystemMessage.create(
      recipient,
      :reviewable_moderation_decision,
      notification_context: context,
      decision:
        I18n.t(
          "dsa_notifications.decisions.#{context.fetch("notice")}",
          locale: recipient.effective_locale,
        ),
      content_reference: reference(context:, locale: recipient.effective_locale),
    )
  end

  def self.template_key(template, context:, locale:)
    return template unless context
    variant =
      if template.match?(
           /\Asystem_messages\.(post_hidden|post_hidden_again|flags_agreed_and_post_deleted|flags_agreed_and_post_deleted_for_responders)\./,
         ) && context.fetch("source") == "review"
        template.sub(/\Asystem_messages\./, "dsa_notifications.")
      elsif template.start_with?("user_notifications.account_deleted.") &&
            (context.fetch("source") == "review" || context.fetch("content_kind", "post") != "post")
        template.sub(/\Auser_notifications\./, "dsa_notifications.")
      end
    return template unless variant
    return template if TranslationOverride.exists?(locale:, translation_key: template)

    variant
  end

  def self.append(body, context, template:, recipient:)
    return body unless context

    locale = recipient&.effective_locale || context.fetch("recipient_locale")
    account_notice =
      template.start_with?("user_notifications.account_") ||
        template == "system_messages.silenced_by_staff"
    primary_recipient = !recipient || context.fetch("post_user_id") == recipient.id
    responder_notice = template == "system_messages.flags_agreed_and_post_deleted_for_responders"
    return body unless account_notice || primary_recipient || responder_notice

    details = []
    if account_notice && primary_recipient
      if context["post_url"]
        details << I18n.t(
          "dsa_notifications.post_reference_#{context.fetch("source")}",
          locale:,
          title: escaped_title(context),
          number: context.fetch("post_number"),
          url: context.fetch("post_url"),
        )
      else
        details << source(context:, locale:)
      end
      if %w[edit delete_all].include?(context.fetch("post_action"))
        details << I18n.t("dsa_notifications.post_actions.#{context.fetch("post_action")}", locale:)
      end
    end
    contact = context.fetch("contact")
    contact_url = context.fetch("contact_email") ? "mailto:#{contact}" : contact
    contact_link = "[#{contact}](#{contact_url})"
    provenance = []
    if !account_notice &&
         (
           context.fetch("source") == "review" ||
             template == "system_messages.reviewable_moderation_decision" ||
             template.start_with?("system_messages.reviewable_queued_post_revise_and_reject") ||
             TranslationOverride.exists?(locale:, translation_key: "#{template}.text_body_template")
         )
      provenance << if responder_notice && !primary_recipient
        I18n.t("dsa_notifications.source_original_post", locale:)
      else
        source(context:, locale:)
      end
    end
    if context.fetch("automated_detection")
      detected_kind = context.fetch("content_kind", "post")
      detected_kind = "account" if detected_kind == "avatar"
      content_key = primary_recipient ? detected_kind : "original_#{detected_kind}"
      detection_key =
        (
          if primary_recipient && detected_kind == "post"
            "detection_automated"
          else
            "detection_automated_content"
          end
        )
      provenance << I18n.t(
        "dsa_notifications.#{detection_key}",
        locale:,
        content: I18n.t("dsa_notifications.content.#{content_key}", locale:),
      )
    end
    if context.fetch("automated_decision") != "AUTOMATED_DECISION_NOT_AUTOMATED"
      provenance << I18n.t(
        "dsa_notifications.decisions_automation.#{context.fetch("automated_decision")}",
        locale:,
      )
    end
    details << provenance.join(" ") if provenance.present?
    details << I18n.t(
      "dsa_notifications.#{responder_notice && !primary_recipient ? "responder_statement" : "statement"}",
      locale:,
      ground: context.fetch("ground"),
      explanation: context.fetch("explanation"),
      general_contact_email: contact_link,
    )
    "#{body.rstrip}\n\n#{details.join("\n\n")}".rstrip
  end

  def self.reference(context:, locale:)
    return "" if context["topic_title"].blank?

    if context["post_url"]
      I18n.t(
        "dsa_notifications.content_reference",
        locale:,
        title: escaped_title(context),
        number: context["post_number"],
        url: context["post_url"],
      )
    else
      I18n.t("dsa_notifications.submission_reference", locale:, title: escaped_title(context))
    end
  end

  def self.source(context:, locale:)
    kind = context.fetch("content_kind", "post")
    key =
      (
        if kind == "post"
          "source_#{context.fetch("source")}"
        else
          "source_#{kind}_#{context.fetch("source")}"
        end
      )
    I18n.t("dsa_notifications.#{key}", locale:)
  end

  def self.escaped_title(context)
    context.fetch("topic_title").to_s.gsub(/[\\\[\]<>*`_]/) { |character| "\\#{character}" }
  end

  private_class_method :reference, :source, :escaped_title
end
