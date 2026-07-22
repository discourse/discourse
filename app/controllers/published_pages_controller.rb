# frozen_string_literal: true

class PublishedPagesController < ApplicationController
  skip_before_action :preload_json
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

    apply_cache_headers!(pp)

    if publicly_cacheable?(pp)
      # stale? sets ETag on the response. Returns true when the
      # client's conditional headers don't match (we must re-render)
      # and false when they do (Rails has already set 304).
      validator = published_page_cache_validator(pp)

      render layout: "publish" if stale?(etag: validator[:etag])
    else
      render layout: "publish"
    end
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
    ensure_logged_in
    guardian.ensure_is_staff!

    pp = PublishedPage.new(topic: Topic.new, slug: params[:slug].strip)

    if pp.valid?
      render json: { valid_slug: true }
    else
      render json: { valid_slug: false, reason: pp.errors.full_messages.first }
    end
  end

  private

  # Whether anonymous /pub/<slug> hits can be cached at a shared cache
  # (CloudFront, etc.). Authenticated requests, pages with public:
  # false, pages whose source topic is in a read-restricted category,
  # and login_required sites are all off-limits: a CDN entry would let
  # an anonymous visitor with the slug bypass guardian / category
  # permission checks the controller enforces above.
  def publicly_cacheable?(pp)
    current_user.nil? && pp.public && !@topic.category&.read_restricted &&
      !SiteSetting.login_required?
  end

  # Sets Cache-Control on the response. Shared caches must revalidate
  # every request because published-page visibility can be revoked by
  # changing the published page, category permissions, or login_required
  # without a CDN purge hook.
  def apply_cache_headers!(pp)
    if publicly_cacheable?(pp)
      response.headers["Cache-Control"] = "public, max-age=60, s-maxage=0, must-revalidate"
      append_vary_header!("Accept", "Accept-Encoding", "Cookie", "User-Agent")
    else
      response.headers["Cache-Control"] = "private, no-store"
    end
  end

  def published_page_cache_validator(pp)
    last_modified = [
      pp.updated_at,
      @topic.updated_at,
      @topic.first_post&.updated_at,
      @topic.user&.updated_at,
    ].compact.max

    {
      etag:
        Digest::SHA1.hexdigest(
          [
            last_modified&.to_f,
            published_page_layout_cache_version,
            published_page_variant_cache_version,
          ].compact.join("\n"),
        ),
    }
  end

  def published_page_layout_cache_version
    [
      Discourse.git_version,
      MessageBus.last_id(Site::SITE_JSON_CHANNEL),
      MessageBus.last_id("/file-change"),
      SiteSetting.title,
      SiteSetting.site_favicon_url,
      SiteSetting.site_apple_touch_icon_url,
      SiteSetting.google_site_verification_token,
      SiteSetting.logo&.id,
      SiteSetting.logo_small&.id,
    ]
  end

  def published_page_variant_cache_version
    [theme_id, MobileDetection.mobile_device?(request.user_agent) ? :mobile : :desktop]
  end

  def append_vary_header!(*values)
    response.headers["Vary"] = (response.headers["Vary"].to_s.split(",").map(&:strip) + values)
      .reject(&:blank?)
      .uniq
      .join(", ")
  end

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
