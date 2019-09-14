# frozen_string_literal: true

# Handle sending a message to a user from the system.

class SystemMessage

  def self.create(recipient, type, params = {})
    self.new(recipient).create(type, params)
  end

  def self.create_from_system_user(recipient, type, params = {})
    params = params.merge(from_system: true)
    self.new(recipient).create(type, params)
  end

  def initialize(recipient)
    @recipient = recipient
  end

  def create(type, params = {})
    params = defaults.merge(params)
    from_system = params[:from_system] || false

    title = I18n.with_locale(@recipient.effective_locale) { I18n.t("system_messages.#{type}.subject_template", params) }
    raw = I18n.with_locale(@recipient.effective_locale) { I18n.t("system_messages.#{type}.text_body_template", params) }

    if from_system
      user = Discourse.system_user
      target_group_names = nil
    else
      user = Discourse.site_contact_user
      target_group_names = Group.exists?(name: SiteSetting.site_contact_group_name) ? SiteSetting.site_contact_group_name : nil
    end

    creator = PostCreator.new(user,
                       title: title,
                       raw: raw,
                       archetype: Archetype.private_message,
                       target_usernames: @recipient.username,
                       target_group_names: target_group_names,
                       subtype: TopicSubtype.system_message,
                       skip_validations: true)

    post = I18n.with_locale(@recipient.effective_locale) { creator.create }

    if creator.errors.present?
      raise StandardError, creator.errors.full_messages.join(" ")
    end

    unless from_system
      UserArchivedMessage.create!(user: Discourse.site_contact_user, topic: post.topic)
    end

    post
  end

  def defaults
    {
      site_name: SiteSetting.title,
      username: @recipient.username,
      user_preferences_url: "#{Discourse.base_url}/u/#{@recipient.username_lower}/preferences",
      new_user_tips: I18n.with_locale(@recipient.effective_locale) { I18n.t('system_messages.usage_tips.text_body_template', base_url: Discourse.base_url) },
      site_password: "",
      base_url: Discourse.base_url,
    }
  end

end
