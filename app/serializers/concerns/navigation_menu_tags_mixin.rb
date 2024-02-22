# frozen_string_literal: true

module NavigationMenuTagsMixin
  def serialize_tags(tags)
    topic_count_column = Tag.topic_count_column(scope)

    tags
      .select(:name, topic_count_column, :pm_topic_count, :description)
      .order(topic_count_column => :desc)
      .map { |tag| SidebarTagSerializer.new(tag, scope: scope, root: false).as_json }
  end
end
