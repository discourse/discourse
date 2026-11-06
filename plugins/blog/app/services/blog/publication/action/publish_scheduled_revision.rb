# frozen_string_literal: true

class Blog::Publication::Action::PublishScheduledRevision < Service::ActionBase
  option :publication
  option :revision

  def call
    error = nil
    publication.transaction(requires_new: true) do
      error = publish_failure
      raise ActiveRecord::Rollback if error
    end
    return if !error
    publication.reload.clear_schedule!(error: error.first(500))
  end

  private

  def publish_failure
    Blog::Publication::Publish.call(
      params: {
        topic_id: publication.topic_id,
        revision_id: revision.id,
      },
      guardian: Guardian.new(publication.scheduler),
    ) do
      on_success { nil }
      on_failed_policy(:blog_ready) { |policy| policy.reason }
      on_failed_policy(:not_published_as_page) { I18n.t("blog.errors.published_page") }
      on_model_errors(:publication) do |publication|
        ActiveRecord::RecordInvalid.new(publication).message
      end
      on_exceptions { |exception| exception.message }
      on_failure { I18n.t("blog.editorial.access_lost") }
    end
  end
end
