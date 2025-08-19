# frozen_string_literal: true

module NavigationMenuTagsMixin
  def serialize_tags(tags)
    topic_count_column = Tag.topic_count_column(scope)

    tags
      .order(topic_count_column => :desc)
      .map { |tag| SidebarTagSerializer.new(tag, scope: scope, root: false).as_json }
  end
end
