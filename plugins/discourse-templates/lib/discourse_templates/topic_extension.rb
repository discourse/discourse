# frozen_string_literal: true

module DiscourseTemplates::TopicExtension
  def self.prepended(base)
    base.has_one :template_item_usage,
                 class_name: "DiscourseTemplates::UsageCount",
                 dependent: :destroy
  end

  def template_item_usage_count
    self.template_item_usage&.usage_count.to_i
  end

  def increment_template_item_usage_count!
    DB.exec(<<~SQL, topic_id: self.id)
      INSERT INTO discourse_templates_usage_count AS uc
      (topic_id, usage_count, created_at, updated_at)
      VALUES
      (:topic_id, 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (topic_id) DO UPDATE SET
        usage_count = uc.usage_count + 1,
        updated_at = CURRENT_TIMESTAMP
        WHERE uc.topic_id = :topic_id
    SQL
  end

  def template?(user)
    parent_categories_ids = SiteSetting.discourse_templates_categories&.split("|")&.map(&:to_i)

    all_templates_categories_ids =
      parent_categories_ids.flat_map { |category_id| Category.subcategory_ids(category_id) }

    # it is template if the topic belongs to any of the template categories
    return true if all_templates_categories_ids.include?(self.category_id)

    unless SiteSetting.tagging_enabled && SiteSetting.discourse_templates_enable_private_templates
      return false
    end

    # or is a private message where the user is the author and at least one tag
    # matches with the tags configured in the plugin for private templates
    private_template_tags = SiteSetting.discourse_templates_private_templates_tags&.split("|")

    archetype == Archetype.private_message && user_id == user&.id &&
      (tags.map(&:name) & private_template_tags).any?
  end
end
