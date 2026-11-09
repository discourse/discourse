# frozen_string_literal: true

module ::Blog
  module TopicExtensions
    def self.prepended(base)
      base.validate :blog_keep_in_drafts_category
      base.after_update :blog_revoke_reviews
      base.before_destroy :blog_destroy_editorial_records
    end

    def duplicate_title_candidates
      candidates = super
      return candidates unless UpcomingChanges.enabled?(:blog_enabled)

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
      if new_record? && Blog::Current.copying_into?(category_id)
        candidates = candidates.where.not(id: Blog::Current.copy_source_id)
      end
      candidates
    end

    # A Blog-category topic whose article has gone live at least once.
    def blog_published_discussion?
      return false if !UpcomingChanges.enabled?(:blog_enabled)
      return false if category_id != SiteSetting.blog_category.to_i
      Blog::Publication.where(discussion_topic_id: id).where.not(published_revision_id: nil).exists?
    end

    def blog_editorial_draft?
      return false if !UpcomingChanges.enabled?(:blog_enabled)
      return false if category_id != SiteSetting.blog_drafts_category.to_i
      # In a public category, editors would gain edit rights over ordinary members' topics.
      return false if !category&.read_restricted?
      return false if category.topic_id == id
      return false if !visible || deleted_at || archived? || private_message?
      !shared_draft?
    end

    def blog_live_publication
      return unless Blog::Configuration.public_enabled?
      return if category_id != SiteSetting.blog_category.to_i
      Blog::Publication.publicly_visible.find_by(discussion_topic_id: id)
    end

    private

    def blog_keep_in_drafts_category
      return unless SiteSetting.blog_enabled
      return if !persisted? || !category_id_changed?
      return if category_id_in_database != SiteSetting.blog_drafts_category.to_i
      errors.add(:category_id, I18n.t("blog.editorial.private_source"))
    end

    def blog_revoke_reviews
      return unless SiteSetting.blog_enabled
      return if !saved_changes.keys.intersect?(%w[category_id deleted_at archetype visible])
      Blog::Review.revoke_for_topic!(id)
    end

    def blog_destroy_editorial_records
      return unless SiteSetting.blog_enabled
      Blog::Review.where(topic_id: id).find_each(&:destroy!)
      Blog::Publication
        .where(topic_id: id)
        .or(Blog::Publication.where(draft_topic_id: id))
        .or(Blog::Publication.where(discussion_topic_id: id))
        .find_each(&:destroy!)
    end
  end
end
