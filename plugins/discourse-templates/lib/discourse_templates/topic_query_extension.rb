# frozen_string_literal: true

module DiscourseTemplates::TopicQueryExtension
  def list_category_templates
    return unless @guardian.can_use_category_templates?

    parent_categories = SiteSetting.discourse_templates_categories&.split("|")&.map(&:to_i)
    all_templates_categories =
      parent_categories.flat_map { |category_id| Category.subcategory_ids(category_id) }

    list =
      default_results(options.reverse_merge(unordered: true, no_definitions: true))
        .references(:category)
        .includes(:first_post)
        .includes(:template_item_usage)
        .where(
          "topics.category_id IN (?)",
          all_templates_categories,
        ) # filter only topics in the configured categories and subs
        .where(visible: true, archived: false) # filter out archived or unlisted topics
        .reorder("topics.title ASC")

    create_list(:templates, {}, list)
  end

  def list_private_templates
    return unless @guardian.can_use_private_templates?

    private_template_tags = SiteSetting.discourse_templates_private_templates_tags&.split("|")

    list = private_messages_for(user, :user).includes(:first_post).includes(:template_item_usage)

    list = not_archived(list, user)

    # a private message is only considered a template if the user is the author and the message
    # is tagged with at least one of the expected tags
    list =
      list
        .where(user_id: user.id)
        .joins(:tags)
        .where("tags.name in (?)", private_template_tags)
        .reorder("topics.title ASC")

    create_list(:templates, {}, list)
  end
end
