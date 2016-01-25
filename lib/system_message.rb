# Handle sending a message to a user from the system.
require_dependency 'post_creator'
require_dependency 'topic_subtype'
require_dependency 'discourse'

class SystemMessage

  def self.create(recipient, type, params = {})
    self.new(recipient).create(type, params)
  end

  def self.create_from_system_user(recipient, type, params = {})
    self.new(recipient).create_from_system_user(type, params)
  end

  def initialize(recipient)
    @recipient = recipient
  end

  def create(type, params = {})
    params = defaults.merge(params)

    title = I18n.t("system_messages.#{type}.subject_template", params)
    raw = I18n.t("system_messages.#{type}.text_body_template", params)

    creator = PostCreator.new(Discourse.site_contact_user,
                       title: title,
                       raw: raw,
                       archetype: Archetype.private_message,
                       target_usernames: @recipient.username,
                       subtype: TopicSubtype.system_message,
                       skip_validations: true)

    post = creator.create
    if creator.errors.present?
      raise StandardError, creator.errors.to_s
    end

    UserArchivedMessage.create!(user: Discourse.site_contact_user, topic: post.topic)

    post
  end

  def create_from_system_user(type, params = {})
    params = defaults.merge(params)

    title = I18n.t("system_messages.#{type}.subject_template", params)
    raw = I18n.t("system_messages.#{type}.text_body_template", params)

    PostCreator.create(Discourse.system_user,
                       title: title,
                       raw: raw,
                       archetype: Archetype.private_message,
                       target_usernames: @recipient.username,
                       subtype: TopicSubtype.system_message)
  end

  def defaults
    {
      site_name: SiteSetting.title,
      username: @recipient.username,
      user_preferences_url: "#{Discourse.base_url}/users/#{@recipient.username_lower}/preferences",
      new_user_tips: I18n.t('system_messages.usage_tips.text_body_template', base_url: Discourse.base_url),
      site_password: "",
      base_url: Discourse.base_url,
    }
  end

end
