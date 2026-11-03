# frozen_string_literal: true

module ::Blog
  module TopicViewExtension
    def canonical_path
      if Configuration.public_enabled? && @page.to_i <= 1 &&
           topic.category_id == SiteSetting.blog_category.to_i
        publication = Publication.publicly_visible.find_by(discussion_topic_id: topic.id)
        return publication.url if publication
      end
      super
    end
  end
end
