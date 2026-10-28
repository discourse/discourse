# frozen_string_literal: true

module ::Blog
  class EditorController < ::ApplicationController
    PAGE_SIZE = 20

    helper Blog::BlogHelper
    requires_plugin PLUGIN_NAME
    requires_login except: [:index]
    before_action :ensure_blog_editor, except: :index
    before_action :ensure_discussion_host
    before_action :find_topic, except: :index
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
                   error: Configuration.error,
                   blog_url: Configuration.origin,
                   more: selected.size > PAGE_SIZE,
                   topics:
                     selected
                       .first(PAGE_SIZE)
                       .map { |topic|
                         entry(
                           topic,
                           publications[topic.id],
                           live: live_topic_ids.include?(topic.id),
                         )
                       },
                 }
        end
      end
    end

    def show
      render json: entry(@topic, @publication)
    end

    def update
      @publication.save_metadata!(
        current_user,
        params.require(:publication).permit(:path, :excerpt, :featured, :published_at),
      )
      render json: entry(@topic, @publication)
    end

    def publish
      # Without a revision, publishers release their current draft in one step.
      revision_id = params[:revision_id].presence&.to_i
      @publication.publish!(current_user, revision_id: revision_id)
      render json: entry(@topic.reload, @publication)
    end

    def changes
      source = @publication.editorial_topic
      live = @publication.published_revision
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
               diff_html: DiscourseDiff.new(live.cooked.to_s, source.first_post.cooked).inline_html,
             }
    rescue ONPDiff::DiffLimitExceeded
      render json: { title_diff_html: nil, diff_html: nil, diff_error: true }
    end

    def prepare
      @publication.prepare_draft!(current_user)
      render json: entry(@publication.topic, @publication)
    end

    def submit
      @publication.submit!(current_user)
      render json: entry(@publication.topic, @publication)
    end

    def approve
      @publication.approve!(current_user, params.require(:revision_id).to_i)
      render json: entry(@publication.topic, @publication)
    end

    def schedule
      @publication.schedule!(
        current_user,
        revision_id: params.require(:revision_id).to_i,
        at: params.require(:scheduled_at),
      )
      render json: entry(@publication.topic, @publication)
    end

    def cancel_schedule
      @publication.cancel_schedule!(current_user)
      head :no_content
    end

    def destroy
      @publication.unpublish!(current_user)
      head :no_content
    end

    def return_to_drafts
      @publication.return_to_drafts!(current_user)
      head :no_content
    end

    def preview
      @preview = true
      @canonical_url = @publication.url
      source = @publication.editorial_topic || @topic
      @article =
        if params[:revision_id].present?
          @publication.revisions.find(params[:revision_id])
        else
          Revision.new(data: Revision.capture(@publication, source))
        end
      @page_title = @article.title
      @description = @article.data["excerpt"]
      response.headers["X-Robots-Tag"] = "noindex, nofollow"
      response.headers["Cache-Control"] = "private, no-store"
      render "blog/articles/show", layout: "blog"
    end

    private

    def ensure_blog_editor
      raise Discourse::InvalidAccess unless Configuration.contributor?(current_user)
    end

    def ensure_discussion_host
      raise Discourse::NotFound if Configuration.blog_host?(request)
    end

    def find_topic
      requested = Topic.find(params[:topic_id])
      @publication = Publication.for_topic(requested)
      @topic = @publication.topic
      Configuration.ensure_editor!(current_user, @publication.editorial_topic || @topic)
    end

    def entry(topic, publication, live: nil)
      publication ||= Publication.new(topic: topic, path: "/#{topic.slug.presence || topic.id}")
      PublicationEntry.new(publication, user: current_user, topic: topic, live: live).to_h
    end
  end
end
