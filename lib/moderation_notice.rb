# frozen_string_literal: true

class ModerationNotice
  def self.enqueue(user:, message_type:, message_options:, post_action_type_id:, delay: 0)
    options = message_options.dup
    for_responders = message_type.to_s == "flags_agreed_and_post_deleted_for_responders"
    reason = flag_reason_for(post_action_type_id:, for_responders:)

    key = options.delete(:flag_reason_suffix_key)
    responder_key = options.delete(:responder_flag_reason_suffix_key)
    key = responder_key || key if for_responders

    if key
      paragraph = I18n.t(key, **options, locale: user.effective_locale)
      reason = "#{reason}\n\n#{paragraph}"
    end

    Jobs.enqueue_in(
      delay,
      :send_system_message,
      user_id: user.id,
      message_type:,
      message_options: options.merge(flag_reason: reason),
    )
  end

  def self.flag_reason_for(post_action_type_id:, for_responders:)
    flag_types = PostActionTypeView.new
    prefix =
      if for_responders
        "flag_reasons.responder"
      else
        "flag_reasons"
      end

    I18n.t(
      "#{prefix}.#{flag_types.types[post_action_type_id]}",
      default: flag_types.names[post_action_type_id],
      locale: SiteSetting.default_locale,
      base_path: Discourse.base_path,
    )
  end
  private_class_method :flag_reason_for
end
