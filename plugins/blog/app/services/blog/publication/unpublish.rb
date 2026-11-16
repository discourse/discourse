# frozen_string_literal: true

class Blog::Publication::Unpublish
  include Service::Base

  params do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic

  transaction do
    model :publication, :lock_publication
    policy :can_publish_article
    step :withdraw_article
    step :log_withdrawal
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def lock_publication(topic:)
    Blog::Publication.lock_existing_for_topic(topic)
  end

  def can_publish_article(guardian:, publication:)
    guardian.can_publish_blog_topic?(publication.editable_topic)
  end

  def withdraw_article(publication:)
    publication.update!(published: false)
    publication.clear_schedule!
  end

  def log_withdrawal(guardian:, publication:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_unpublish",
      topic_id: publication.topic_id,
    )
  end
end
