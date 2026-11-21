# frozen_string_literal: true

# Handle sending a message to a user from the system.

class SystemMessage
  def self.create(recipient, type, params = {})
    new(recipient).create(type, params)
  end

  def self.create_from_system_user(recipient, type, params = {})
    params = params.merge(from_system: true)
    new(recipient).create(type, params)
  end

  def initialize(recipient)
    @recipient = recipient
  end

  def create(type, params = {})
    method_params = params.dup

    from_system = params.delete(:from_system)
    target_group_names = params.delete(:target_group_names)

    params = defaults.merge(params)

    if I18n.exists?("system_messages.#{type}.preview", @recipient.effective_locale)
      params[:email_preview] = I18n.t("system_messages.#{type}.preview", params)
    end

    title =
      params[:message_title] ||
        I18n.with_locale(@recipient.effective_locale) do
          I18n.t("system_messages.#{type}.subject_template", params)
        end
    raw =
      params[:message_raw] ||
        I18n.with_locale(@recipient.effective_locale) do
          translate_body("system_messages.#{type}.text_body_template", params)
        end
    raw =
      Dsa::ModerationGuideline.append_to(
        raw,
        rule: params[:community_rule],
        locale: @recipient.effective_locale,
        for_responders: params[:community_rule_for_responders],
      )

    if key = params[:body_suffix_key]
      paragraph = I18n.with_locale(@recipient.effective_locale) { I18n.t(key, params) }
      raw = "#{raw.rstrip}\n\n#{paragraph}"
    end

    if from_system
      user = Discourse.system_user
    else
      user = Discourse.site_contact_user
      target_group_names = Discourse.site_contact_group&.name
    end

    post_creator_args = [
      user,
      title: title,
      raw: raw,
      archetype: Archetype.private_message,
      target_usernames: @recipient.username,
      target_group_names: target_group_names,
      subtype: TopicSubtype.system_message,
      skip_validations: true,
      post_alert_options: params[:post_alert_options],
    ]

    DiscourseEvent.trigger(
      :before_system_message_sent,
      message_type: type,
      recipient: @recipient,
      post_creator_args: post_creator_args,
      params: method_params,
    )

    creator = PostCreator.new(*post_creator_args)

    post = I18n.with_locale(@recipient.effective_locale) { creator.create }

    DiscourseEvent.trigger(
      :system_message_sent,
      post: post,
      message_type: type,
      recipient: @recipient,
    )

    raise StandardError, creator.errors.full_messages.join(" ") if creator.errors.present?

    unless from_system
      UserArchivedMessage.create!(user: Discourse.site_contact_user, topic: post.topic)
    end

    post
  end

  def defaults
    {
      site_name: SiteSetting.title,
      username: @recipient.username,
      name: @recipient.name,
      name_or_username: @recipient.name.presence || @recipient.username,
      user_preferences_url: "#{@recipient.full_url}/preferences",
      new_user_tips:
        I18n.with_locale(@recipient.effective_locale) do
          I18n.t("system_messages.usage_tips.text_body_template", base_url: Discourse.base_url)
        end,
      site_password: "",
      base_url: Discourse.base_url,
      email_preview: "",
    }
  end

  private

  def translate_body(key, params)
    return I18n.t(key, params) unless params[:community_rule] && params[:flagged_post_raw_content]

    template = I18n.t(key, skip_interpolation: true)
    template =
      template.gsub(
        /^(?<indent> {0,3})(?<fence>`{2,}|~{3,})(?<language>[^\n]*)\n%\{(?<content>flagged_post_(?:response_)?raw_content)\}\n(?<closing_indent> {0,3})\k<fence>[ \t]*$/,
      ) do |block|
        match = Regexp.last_match
        fence = match[:fence]
        longest_run =
          params[match[:content].to_sym].to_s.scan(/#{fence[0]}+/).map(&:length).max.to_i
        fence_length = [3, longest_run + 1].max
        next block if fence_length <= fence.length

        fence = fence[0] * fence_length
        "#{match[:indent]}#{fence}#{match[:language]}\n%{#{match[:content]}}\n#{match[:closing_indent]}#{fence}"
      end
    I18n.interpolate(template, params)
  end
end
