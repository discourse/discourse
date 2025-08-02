# frozen_string_literal: true

DiscourseAutomation::Scriptable.add(DiscourseAutomation::Scripts::TOPIC) do
  version 1

  field :creator, component: :user
  field :creator, component: :user, triggerable: :user_updated, accepted_contexts: [:updated_user]

  field :body, component: :post, required: true, accepts_placeholders: true
  field :title, component: :text, required: true, accepts_placeholders: true
  field :category, component: :category, required: true
  field :tags, component: :tags

  placeholder :creator_username
  placeholder :updated_user_username, triggerable: :user_updated
  placeholder :updated_user_name, triggerable: :user_updated

  triggerables %i[recurring point_in_time user_updated]

  script do |context, fields, automation|
    creator_username = fields.dig("creator", "value")
    creator_username = context["user"]&.username if creator_username == "updated_user"
    creator_username ||= Discourse.system_user.username

    placeholders = { creator_username: creator_username }.merge(context["placeholders"] || {})

    if context["kind"] == DiscourseAutomation::Triggers::USER_UPDATED
      user = context["user"]
      user_data = context["user_data"]
      user_profile_data = user_data[:profile_data] || {}
      user_custom_fields = {}
      user_data[:custom_fields]&.each do |k, v|
        user_custom_fields[k.gsub(/\s+/, "_").underscore] = v
      end
      user = User.find(context["user"].id)
      placeholders["username"] = user.username
      placeholders["name"] = user.name
      placeholders["updated_user_username"] = user.username
      placeholders["updated_user_name"] = user.name
      placeholders = placeholders.merge(user_profile_data, user_custom_fields)
    end

    topic_raw = fields.dig("body", "value")
    topic_raw = utils.apply_placeholders(topic_raw, placeholders)

    title = fields.dig("title", "value")
    title = utils.apply_placeholders(title, placeholders)

    creator = User.find_by(username: creator_username)
    if !creator
      Rails.logger.warn "[discourse-automation] creator with username: `#{creator_username}` was not found"
      next
    end

    category_id = fields.dig("category", "value")
    category = Category.find_by(id: category_id)
    if !category
      Rails.logger.warn "[discourse-automation] category of id: `#{category_id}` was not found"
      next
    end

    tags = fields.dig("tags", "value") || []
    begin
      new_post =
        PostCreator.new(
          creator,
          raw: topic_raw,
          title: title,
          category: category.id,
          tags: tags,
        ).create!
    rescue StandardError => e
      Rails.logger.warn "[discourse-automation] couldn't create post: #{e.message}"
      next
    end

    if context["kind"] == DiscourseAutomation::Triggers::USER_UPDATED && new_post.persisted?
      user.user_custom_fields.create(name: automation.name, value: "true")
    end
  end
end
