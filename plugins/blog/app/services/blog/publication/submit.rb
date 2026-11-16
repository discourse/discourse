# frozen_string_literal: true

class Blog::Publication::Submit
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
    model :working_copy, :lock_working_copy
    policy :can_edit_working_copy
    policy :working_copy_publishable
    model :revision, :create_revision
    step :await_approval
    step :log_submission
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

  def lock_working_copy(publication:)
    publication.editorial_topic.lock!.tap { |working_copy| working_copy.first_post&.lock! }
  end

  def can_edit_working_copy(guardian:, working_copy:)
    guardian.can_edit_blog_topic?(working_copy)
  end

  def working_copy_publishable(publication:, working_copy:)
    publication.publishable_source?(working_copy)
  end

  def create_revision(guardian:, publication:, working_copy:)
    publication.revisions.create!(
      source_topic: working_copy,
      creator: guardian.user,
      data: Blog::Revision.capture(publication, working_copy),
    )
  end

  def await_approval(publication:, revision:)
    publication.update!(submitted_revision: revision, approved_revision: nil)
  end

  def log_submission(guardian:, publication:, revision:)
    StaffActionLogger.new(guardian.user).log_custom(
      "blog_submit",
      topic_id: publication.topic_id,
      revision_id: revision.id,
    )
  end
end
