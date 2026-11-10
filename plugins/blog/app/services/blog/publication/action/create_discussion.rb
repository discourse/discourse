# frozen_string_literal: true

class Blog::Publication::Action::CreateDiscussion < Service::ActionBase
  option :publication
  option :revision
  option :working_copy
  option :guardian

  def call
    creator =
      PostCreator.new(
        working_copy.user || guardian.user,
        raw: revision.raw,
        title: revision.title,
        tags: revision.data["tags"],
        category: blog_category_id,
        guardian:,
        acting_user: guardian.user,
        skip_jobs: true,
      )
    post = publication.copy_post!(creator, working_copy, blog_category_id)
    publication.discussion_topic = post.topic
    DB.after_commit { creator.enqueue_jobs }
  end

  private

  def blog_category_id
    SiteSetting.blog_category.to_i
  end
end
