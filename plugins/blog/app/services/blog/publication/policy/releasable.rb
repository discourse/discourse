# frozen_string_literal: true

class Blog::Publication::Policy::Releasable < Service::PolicyBase
  delegate :publication, :revision, :working_copy, to: :context, private: true

  def call
    return false if !publication.publishable_source?(working_copy)
    return false if !guardian.can_publish_blog_topic?(working_copy)
    return false if !Guardian.new(revision.approver).can_publish_blog_topic?(working_copy)
    return false if !guardian.can_create_topic_on_category?(SiteSetting.blog_category.to_i)
    discussion_open?
  end

  def reason
    I18n.t("blog.editorial.access_lost")
  end

  private

  def discussion_open?
    discussion = publication.discussion_topic
    return true if !discussion
    return false if !guardian.can_see?(discussion)
    return false if discussion.category_id != SiteSetting.blog_category.to_i
    return false if discussion.deleted_at || discussion.archived? || discussion.shared_draft?
    return false if !discussion.visible
    post = discussion.first_post
    post.present? && !post.hidden?
  end
end
