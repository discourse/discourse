# frozen_string_literal: true

module ::Blog
  class EditorController < ::ApplicationController
    PAGE_SIZE = 20

    helper Blog::BlogHelper
    requires_plugin PLUGIN_NAME
    requires_login except: [:index]
    before_action :ensure_blog_editor, except: :index
    before_action :ensure_discussion_host
    skip_before_action :check_xhr, only: %i[index preview]

    def index
      ensure_blog_editor unless request.format.html? && !current_user
      respond_to do |format|
        format.html { render "default/empty" }
        format.json do
          topics =
            EditorQuery.call(
              guardian,
              filter: params[:filter].presence || "all",
              query: params[:q] || "",
            )
          @page = [params[:page].to_i, 0].max
          selected =
            topics
              .offset(@page * PAGE_SIZE)
              .limit(PAGE_SIZE + 1)
              .includes(:first_post, :category)
              .to_a
          publications =
            Publication
              .where(topic_id: selected.map(&:id))
              .includes(
                :discussion_topic,
                :submitted_revision,
                :approved_revision,
                :published_revision,
                topic: :first_post,
                draft_topic: :first_post,
              )
              .index_by(&:topic_id)
          live_topic_ids =
            Publication.publicly_visible.where(topic_id: selected.map(&:id)).pluck(:topic_id).to_set
          render json: {
                   error: Readiness.new.error,
                   blog_url: Configuration.base_url,
                   more: selected.size > PAGE_SIZE,
                   topics:
                     selected
                       .first(PAGE_SIZE)
                       .map { |topic|
                         publication =
                           publications[topic.id] ||
                             Publication.new(topic:, path: "/#{topic.slug.presence || topic.id}")
                         serialize_publication(publication, live: live_topic_ids.include?(topic.id))
                       },
                 }
        end
      end
    end

    def show
      render json: serialize_publication(find_editable_publication)
    end

    def update
      Publication::UpdateMetadata.call(
        service_params.deep_merge(params: { metadata: metadata_params }),
      ) do
        on_success { |publication:| render json: serialize_publication(publication) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:blog_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_model_errors(:publication) do |publication|
          raise ActiveRecord::RecordInvalid.new(publication)
        end
        on_failed_policy(:can_edit_article) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_use_cover_upload) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def publish
      Publication::Publish.call(service_params) do
        on_success { |publication:| render json: serialize_publication(publication) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_errors(:publication) do |publication|
          raise ActiveRecord::RecordInvalid.new(publication)
        end
        on_failed_policy(:can_publish_article) { raise Discourse::InvalidAccess }
        on_failed_policy(:blog_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failed_step(:submit_current_draft) { raise Discourse::InvalidAccess }
        on_failed_step(:approve_current_draft) do |step|
          raise Discourse::InvalidParameters.new(step.error)
        end
        on_model_not_found(:revision) { raise Discourse::NotFound }
        on_failed_policy(:revision_awaits_release) do
          raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.stale"))
        end
        on_model_not_found(:working_copy) { raise Discourse::InvalidAccess }
        on_failed_policy(:releasable) { raise Discourse::InvalidAccess }
        on_failed_policy(:not_published_as_page) do
          raise Discourse::InvalidParameters.new(I18n.t("blog.errors.published_page"))
        end
        on_exceptions(ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved) do |exception|
          raise exception
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def changes
      publication = find_editable_publication
      source = publication.editorial_topic
      live = publication.published_revision
      raise Discourse::NotFound unless live && source&.first_post

      title_diff =
        if source.title != live.title
          DiscourseDiff.new(
            "<div>#{CGI.escapeHTML(live.title.to_s)}</div>",
            "<div>#{CGI.escapeHTML(source.title)}</div>",
          ).inline_html
        end
      render json: {
               title_diff_html: title_diff,
               diff_html:
                 DiscourseDiff.new(
                   publication.article.cooked.to_s,
                   source.first_post.cooked,
                 ).inline_html,
             }
    rescue ONPDiff::DiffLimitExceeded
      render json: { title_diff_html: nil, diff_html: nil, diff_error: true }
    end

    def prepare
      Publication::PrepareDraft.call(service_params) do
        on_success { |publication:| render json: serialize_publication(publication) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_errors(:publication) do |publication|
          raise ActiveRecord::RecordInvalid.new(publication)
        end
        on_failed_policy(:can_edit_article) { raise Discourse::InvalidAccess }
        on_failed_policy(:blog_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failed_policy(:draftable) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def submit
      Publication::Submit.call(service_params) do
        on_success { |publication:| render json: serialize_publication(publication) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_errors(:publication) do |publication|
          raise ActiveRecord::RecordInvalid.new(publication)
        end
        on_failed_policy(:can_edit_article) { raise Discourse::InvalidAccess }
        on_failed_policy(:blog_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failed_policy(:draftable) { raise Discourse::InvalidAccess }
        on_failed_policy(:can_edit_working_copy) { raise Discourse::InvalidAccess }
        on_failed_policy(:working_copy_publishable) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def approve
      Publication::Approve.call(service_params) do
        on_success { |publication:| render json: serialize_publication(publication) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_errors(:publication) do |publication|
          raise ActiveRecord::RecordInvalid.new(publication)
        end
        on_failed_policy(:can_publish_article) { raise Discourse::InvalidAccess }
        on_model_not_found(:revision) { raise Discourse::NotFound }
        on_failed_policy(:revision_is_latest_submission) do
          raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.stale"))
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def schedule
      Publication::Schedule.call(service_params) do
        on_success { |publication:| render json: serialize_publication(publication) }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_not_found(:publication) { raise Discourse::NotFound }
        on_failed_policy(:can_publish_article) { raise Discourse::InvalidAccess }
        on_failed_policy(:blog_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_model_not_found(:revision) { raise Discourse::NotFound }
        on_failed_policy(:revision_is_approved) do
          raise Discourse::InvalidParameters.new(I18n.t("blog.editorial.approval_required"))
        end
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def cancel_schedule
      Publication::CancelSchedule.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_not_found(:publication) { raise Discourse::NotFound }
        on_failed_policy(:can_publish_article) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def destroy
      Publication::Unpublish.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_not_found(:publication) { raise Discourse::NotFound }
        on_failed_policy(:can_publish_article) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def return_to_drafts
      Publication::ReturnToDrafts.call(service_params) do
        on_success { head :no_content }
        on_failed_contract do |contract|
          raise Discourse::InvalidParameters.new(contract.errors.full_messages.first)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_not_found(:publication) { raise Discourse::NotFound }
        on_failed_policy(:can_publish_article) { raise Discourse::InvalidAccess }
        on_failed_policy(:blog_ready) do |policy|
          raise Discourse::InvalidParameters.new(policy.reason)
        end
        on_failed_policy(:draftable) { raise Discourse::InvalidAccess }
        on_failure { render(json: failed_json, status: :unprocessable_entity) }
      end
    end

    def preview
      @publication = find_editable_publication
      @topic = @publication.topic
      @preview = true
      @canonical_url = @publication.url
      source = @publication.editable_topic
      revision =
        if params[:revision_id].present?
          @publication.revisions.find(params[:revision_id])
        else
          Revision.new(data: Revision.capture(@publication, source))
        end
      @page_title = revision.title
      @description = revision.data["meta_description"].presence || revision.data["excerpt"]
      @article_metadata = ArticleMetadata.new(@publication, revision:, description: @description)
      @template_variables =
        TemplateVariables.new(
          title: @page_title,
          article: ArticleVariables.new(@publication, revision:, topic: @topic),
        )
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
      response.headers["Cache-Control"] = "private, no-store"
      render "blog/articles/show", layout: "blog"
    end

    private

    def ensure_blog_editor
      raise Discourse::InvalidAccess unless guardian.is_blog_contributor?
    end

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end

    def find_editable_publication
      publication = Publication.for_topic(Topic.find(params[:topic_id]))
      guardian.ensure_can_edit_blog_topic!(publication.editable_topic)
      publication
    end

    def serialize_publication(publication, **options)
      PublicationSerializer.new(publication, scope: guardian, root: false, **options).as_json
    end

    def metadata_params
      params
        .require(:publication)
        .permit(
          :path,
          :excerpt,
          :featured,
          :published_at,
          :meta_description,
          :canonical_url,
          :cover_upload_id,
          :cover_alt,
          :co_authors,
        )
        .to_h
    end
  end
end
