# frozen_string_literal: true

class PostRevision::Unlist
  include Service::Base

  params do
    attribute :post_id, :integer
    attribute :revision, :integer

    validates :post_id, :revision, presence: true
  end

  model :post
  policy :can_see_post

  transaction do
    model :post_revision
    policy :can_unlist_post_revision
    policy :post_revision_not_hidden
    step :unlist
  end

  private

  def fetch_post(params:)
    # Staff can still see posts in a trashed topic, which the default topic scope hides.
    Post
      .with_deleted
      .find_by(id: params.post_id)
      &.tap { |post| post.topic ||= Topic.with_deleted.find_by(id: post.topic_id) }
  end

  def can_see_post(guardian:, post:)
    guardian.can_see?(post)
  end

  def fetch_post_revision(params:, post:)
    # Locked so a concurrent hide can't land between the hidden check and the write.
    post.revisions.lock.find_by(number: params.revision)
  end

  def can_unlist_post_revision(guardian:, post_revision:)
    guardian.can_unlist_post_revision?(post_revision)
  end

  def post_revision_not_hidden(post_revision:)
    !post_revision.hidden
  end

  def unlist(post_revision:)
    post_revision.unlist!
  end
end
