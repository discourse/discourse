# frozen_string_literal: true

class Blog::Publication::RunSchedule
  include Service::Base

  params do
    attribute :publication_id, :integer
    attribute :token, :string

    validates :publication_id, :token, presence: true
  end

  model :publication

  transaction do
    step :lock_publication
    policy :schedule_due
    model :revision
    step :publish_scheduled_revision
  end

  private

  def fetch_publication(params:)
    Blog::Publication.find_by(id: params.publication_id)
  end

  def lock_publication(publication:)
    publication.topic.lock!
    publication.reload
  end

  def schedule_due(params:, publication:)
    return false if publication.schedule_token != params.token
    return false if !publication.scheduled_at
    publication.scheduled_at <= Time.current
  end

  def fetch_revision(publication:)
    publication.scheduled_revision
  end

  def publish_scheduled_revision(publication:, revision:)
    Blog::Publication::Action::PublishScheduledRevision.call(publication:, revision:)
  end
end
