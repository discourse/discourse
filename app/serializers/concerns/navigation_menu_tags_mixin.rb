# frozen_string_literal: true

module NavigationMenuTagsMixin
  def serialize_tags(tags)
    topic_count_column = Tag.topic_count_column(scope)

    ordered_tags = tags.order(topic_count_column => :desc).to_a

    if SiteSetting.content_localization_enabled
      ActiveRecord::Associations::Preloader.new(
        records: ordered_tags,
        associations: :localizations,
      ).call
    end

    ordered_tags.map { |tag| SidebarTagSerializer.new(tag, scope: scope, root: false).as_json }
  end
end
