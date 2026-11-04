# frozen_string_literal: true

module ::Blog
  module TopicViewExtension
    def canonical_path
      if @page.to_i <= 1 && (publication = topic.blog_live_publication)
        return publication.url
      end
      super
    end
  end
end
