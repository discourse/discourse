# frozen_string_literal: true

module ::Blog
  class PublicationSerializer < ApplicationSerializer
    attributes :id,
               :role,
               :status,
               :title,
               :public_title,
               :public_excerpt,
               :public_path,
               :draft_correction,
               :changes,
               :edits_since_publish,
               :draft_updated_at,
               :topic_url,
               :source_topic_id,
               :source_url,
               :discussion_url,
               :preview_url,
               :url,
               :path,
               :excerpt,
               :meta_description,
               :canonical_url,
               :featured,
               :published_at,
               :last_published_at,
               :published,
               :published_revision_id,
               :live,
               :draft,
               :replies,
               :can_publish,
               :review_feedback_count,
               :active_review_links,
               :awaiting_approval,
               :submitted_revision,
               :approved_revision,
               :scheduled_revision,
               :scheduled_at,
               :schedule_error

    def id
      object.topic.id
    end

    def role
      viewed_topic = @options[:viewed_topic]
      return "source" if !viewed_topic
      return "draft" if viewed_topic.id == working_copy&.id
      # Any public Blog-category topic is a discussion, whether or not it has been published yet.
      return "discussion" if viewed_topic.id == object.discussion_topic_id
      return "discussion" if viewed_topic.category_id == SiteSetting.blog_category.to_i
      "source"
    end

    def status
      return "scheduled" if object.scheduled_at
      return "unpublished" if !object.published? && object.published_revision_id
      return "changes_pending" if object.published? && pending_changes.any?
      object.published? ? "live" : "draft"
    end

    def title
      working_copy&.title || object.topic.title
    end

    def public_title
      object.published_revision&.title
    end

    def public_excerpt
      object.published_revision&.data&.[]("excerpt")
    end

    def public_path
      object.published_revision&.data&.[]("path")
    end

    def draft_correction
      pending_changes.any?
    end

    def changes
      pending_changes
    end

    def draft_updated_at
      working_copy&.first_post&.updated_at
    end

    def topic_url
      working_copy&.url || object.topic.url
    end

    def source_topic_id
      working_copy&.id
    end

    def source_url
      working_copy&.url
    end

    def discussion_url
      object.discussion_topic&.url
    end

    def path
      metadata["path"]
    end

    def excerpt
      metadata["excerpt"]
    end

    def meta_description
      metadata["meta_description"].to_s
    end

    def canonical_url
      metadata["canonical_url"].to_s
    end

    def featured
      metadata["featured"]
    end

    def published_at
      metadata["published_at"]
    end

    def published
      object.published?
    end

    def live
      return object.publicly_visible? if @options[:live].nil?
      @options[:live]
    end

    def draft
      !object.published? && working_copy.present?
    end

    def replies
      [object.discussion_topic&.posts_count.to_i - 1, 0].max
    end

    def can_publish
      scope.is_blog_publisher?
    end

    def review_feedback_count
      return 0 if !working_copy
      ReviewFeedback.joins(:review).where(blog_reviews: { topic_id: working_copy.id }).count
    end

    def active_review_links
      return 0 if !working_copy
      Review.where(topic_id: working_copy.id).unexpired.count
    end

    # Scheduling submits and approves in one step, so only an unapproved submission is waiting.
    def awaiting_approval
      submitted = object.submitted_revision_id
      return false if submitted.blank?
      submitted != object.published_revision_id && submitted != object.approved_revision_id
    end

    def submitted_revision
      serialize_revision(object.submitted_revision)
    end

    def approved_revision
      serialize_revision(object.approved_revision)
    end

    def scheduled_revision
      serialize_revision(object.scheduled_revision)
    end

    private

    def working_copy
      object.editorial_topic
    end

    def metadata
      @metadata ||= object.editorial_metadata
    end

    def pending_changes
      @pending_changes ||= object.pending_changes
    end

    def serialize_revision(revision)
      return if !revision
      PublicationRevisionSerializer.new(revision, root: false, publication: object).as_json
    end
  end
end
