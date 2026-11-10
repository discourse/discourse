# frozen_string_literal: true

class Blog::Publication::Action::PrepareWorkingCopy < Service::ActionBase
  option :publication
  option :guardian

  def call
    publication.save! if publication.new_record?
    return if publication.draft_topic_id
    publication.update!(draft_topic: publication.editorial_topic || copy_into_drafts)
  end

  private

  def copy_into_drafts
    source = publication.discussion_topic || publication.topic
    creator =
      PostCreator.new(
        source.user || guardian.user,
        title: source.title,
        raw: source.first_post.raw,
        tags: source.tags.visible(Guardian.new).pluck(:name),
        category: drafts_category_id,
        guardian:,
        acting_user: guardian.user,
        skip_jobs: true,
      )
    post = publication.copy_post!(creator, source, drafts_category_id)
    post.topic.update!(image_upload_id: source.image_upload_id)
    DB.after_commit { creator.enqueue_jobs }
    post.topic
  end

  def drafts_category_id
    SiteSetting.blog_drafts_category.to_i
  end
end
