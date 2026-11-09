# frozen_string_literal: true

class Blog::Publication::PrepareDraft
  include Service::Base

  params do
    attribute :topic_id, :integer

    validates :topic_id, presence: true
  end

  model :topic

  transaction do
    model :publication, :lock_publication
    policy :can_edit_article
    policy :blog_ready, class_name: Blog::Policy::Ready
    policy :draftable
    step :prepare_working_copy
  end

  private

  def fetch_topic(params:)
    Topic.find_by(id: params.topic_id)
  end

  def lock_publication(topic:)
    Blog::Publication.lock_for_topic(topic)
  end

  def can_edit_article(guardian:, publication:)
    guardian.can_edit_blog_topic?(publication.editable_topic)
  end

  def draftable(publication:)
    publication.draftable?
  end

  def prepare_working_copy(guardian:, publication:)
    Blog::Publication::Action::PrepareWorkingCopy.call(publication:, guardian:)
  end
end
