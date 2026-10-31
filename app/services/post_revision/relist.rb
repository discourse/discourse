# frozen_string_literal: true

class PostRevision::Relist
  include Service::Base

  params do
    attribute :post_id, :integer
    attribute :revision, :integer

    validates :post_id, :revision, presence: true
  end

  model :post
  policy :can_see_post
  model :post_revision
  policy :can_relist_post_revision
  step :relist

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
    post.revisions.find_by(number: params.revision)
  end

  def can_relist_post_revision(guardian:, post_revision:)
    guardian.can_relist_post_revision?(post_revision)
  end

  def relist(post_revision:)
    post_revision.relist!
  end
end
