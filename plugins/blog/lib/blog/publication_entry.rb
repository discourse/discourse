# frozen_string_literal: true

module ::Blog
  # The editorial view of one article, shared by the editor endpoints and the topic page.
  class PublicationEntry
    def self.for_viewer(topic, user)
      return unless SiteSetting.blog_enabled
      return if topic.private_message?
      categories = [SiteSetting.blog_category.to_i, SiteSetting.blog_drafts_category.to_i]
      return if categories.exclude?(topic.category_id)
      return unless Configuration.contributor?(user)

      publication = Publication.for_topic(topic)
      Configuration.ensure_editor!(user, publication.editorial_topic || publication.topic)
      new(publication, user: user, viewed_topic: topic).to_h
    rescue Discourse::InvalidAccess
      nil
    end

    def initialize(publication, user:, topic: nil, viewed_topic: nil, live: nil)
      @publication = publication
      @user = user
      @topic = topic || publication.topic
      @viewed_topic = viewed_topic
      @live = live
    end

    def to_h
      source = publication.editorial_topic
      metadata = publication.editorial_metadata
      changes = publication.pending_changes
      {
        id: topic.id,
        role: role,
        status: status(changes),
        title: source&.title || topic.title,
        public_title: publication.published_revision&.title,
        public_excerpt: publication.published_revision&.data&.[]("excerpt"),
        public_path: publication.published_revision&.data&.[]("path"),
        draft_correction: changes.any?,
        changes: changes,
        edits_since_publish: publication.edits_since_publish,
        draft_updated_at: source&.first_post&.updated_at,
        topic_url: source&.url || topic.url,
        source_topic_id: source&.id,
        source_url: source&.url,
        discussion_url: publication.discussion_topic&.url,
        preview_url: publication.preview_url,
        url: publication.url,
        path: metadata["path"],
        excerpt: metadata["excerpt"],
        featured: metadata["featured"],
        published_at: metadata["published_at"],
        last_published_at: publication.last_published_at,
        published: publication.published?,
        published_revision_id: publication.published_revision_id,
        live: live.nil? ? publication.publicly_visible? : live,
        draft: !publication.published? && source.present?,
        replies: [publication.discussion_topic&.posts_count.to_i - 1, 0].max,
        can_publish: Configuration.publisher?(user),
        review_feedback_count: source ? feedback_count(source) : 0,
        active_review_links: source ? Review.where(topic_id: source.id).unexpired.count : 0,
        submitted_revision: revision_entry(publication.submitted_revision),
        approved_revision: revision_entry(publication.approved_revision),
        scheduled_revision: revision_entry(publication.scheduled_revision),
        scheduled_at: publication.scheduled_at,
        schedule_error: publication.schedule_error,
      }
    end

    private

    attr_reader :publication, :user, :topic, :viewed_topic, :live

    def role
      return "source" unless viewed_topic
      return "draft" if viewed_topic.id == publication.editorial_topic&.id
      # Any public Blog-category topic is a discussion, whether or not it has been published yet.
      if viewed_topic.id == publication.discussion_topic_id ||
           viewed_topic.category_id == SiteSetting.blog_category.to_i
        return "discussion"
      end
      "source"
    end

    def status(changes)
      return "scheduled" if publication.scheduled_at
      return "unpublished" if !publication.published? && publication.published_revision_id
      return "changes_pending" if publication.published? && changes.any?
      publication.published? ? "live" : "draft"
    end

    def feedback_count(source)
      ReviewFeedback.joins(:review).where(blog_reviews: { topic_id: source.id }).count
    end

    def revision_entry(revision)
      return nil unless revision
      {
        id: revision.id,
        title: revision.title,
        approved_by: revision.approver&.username,
        preview_url: "#{publication.preview_url}?revision_id=#{revision.id}",
      }
    end
  end
end
