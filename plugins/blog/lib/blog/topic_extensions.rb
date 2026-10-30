# frozen_string_literal: true

module ::Blog
  module TopicExtensions
    def duplicate_title_candidates
      candidates = super
      return candidates unless SiteSetting.blog_enabled

      publication =
        Blog::Publication
          .where(draft_topic_id: id)
          .or(Blog::Publication.where(discussion_topic_id: id))
          .first if persisted?
      if publication
        candidates =
          candidates.where.not(
            id: [publication.draft_topic_id, publication.discussion_topic_id].compact,
          )
      end
      copy = Thread.current[:blog_copy]
      if new_record? && copy && category_id == copy[:category_id]
        candidates = candidates.where.not(id: copy[:source_id])
      end
      candidates
    end
  end
end
