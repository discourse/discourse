# frozen_string_literal: true

class PublishedPagesController < ApplicationController
  skip_before_action :check_xhr, :verify_authenticity_token, only: [:show]
  before_action :ensure_publish_enabled
  before_action :redirect_to_login_if_required, :redirect_to_profile_if_required, except: [:show]

  def show
    params.require(:slug)

    pp = PublishedPage.find_by(slug: params[:slug])
    raise Discourse::NotFound unless pp

    return if enforce_login_required!

    if !pp.public
      begin
        guardian.ensure_can_see!(pp.topic)
      rescue Discourse::InvalidAccess => e
        return(
          rescue_discourse_actions(
            :invalid_access,
            403,
            include_ember: false,
            custom_message: e.custom_message,
            group: e.group,
          )
        )
      end
    end

    @topic = pp.topic
    @canonical_url = @topic.url
    @logo = SiteSetting.logo_small || SiteSetting.logo
    @site_url = Discourse.base_url
    @border_color = "#" + ColorScheme.base_colors["tertiary"]

    TopicViewItem.add(pp.topic.id, request.remote_ip, current_user ? current_user.id : nil)

    @body_classes =
      Set.new(
        [
          "published-page",
          params[:slug],
          "topic-#{@topic.id}",
          @topic.tags.pluck(:name),
        ].flatten.compact,
      )

    @body_classes << @topic.category.slug if @topic.category

    render layout: "publish"
  end

  def details
    pp = PublishedPage.find_by(topic: fetch_topic)
    raise Discourse::NotFound if pp.blank?
    render_serialized(pp, PublishedPageSerializer)
  end

  def upsert
    pp_params = params.require(:published_page)

    result, pp =
      PublishedPage.publish!(
        current_user,
        fetch_topic,
        pp_params[:slug].strip,
        pp_params.permit(:public),
      )

    json_result(pp, serializer: PublishedPageSerializer) { result }
  end

  def destroy
    PublishedPage.unpublish!(current_user, fetch_topic)
    render json: success_json
  end

  def check_slug
    pp = PublishedPage.new(topic: Topic.new, slug: params[:slug].strip)

    if pp.valid?
      render json: { valid_slug: true }
    else
      render json: { valid_slug: false, reason: pp.errors.full_messages.first }
    end
  end

  private

  def fetch_topic
    topic = Topic.find_by(id: params[:topic_id])
    guardian.ensure_can_publish_page!(topic)
    topic
  end

  def ensure_publish_enabled
    raise Discourse::NotFound if !SiteSetting.enable_page_publishing? || SiteSetting.secure_uploads
  end

  def enforce_login_required!
    if SiteSetting.login_required? && !current_user &&
         !SiteSetting.show_published_pages_login_required? && redirect_to_login
      true
    end
  end
end
