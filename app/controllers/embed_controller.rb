# frozen_string_literal: true

class EmbedController < ApplicationController
  include TopicQueryParams

  skip_before_action :check_xhr, :verify_authenticity_token

  before_action :prepare_embeddable, except: [:info]
  before_action :ensure_api_request, only: [:info]

  layout "embed"

  rescue_from Discourse::InvalidAccess do
    if current_user.try(:admin?)
      @setup_url = "#{Discourse.base_url}/admin/customize/embedding"
      @show_reason = true
      @hosts = EmbeddableHost.all
    end
    render "embed_error", status: 400
  end

  def topics
    discourse_expires_in 1.minute

    unless SiteSetting.embed_topics_list?
      render "embed_topics_error", status: 400
      return
    end

    if @embed_id = params[:discourse_embed_id]
      raise Discourse::InvalidParameters.new(:embed_id) unless @embed_id =~ /\Ade\-[a-zA-Z0-9]+\z/
    end

    if @embed_class = params[:embed_class]
      unless @embed_class =~ /\A[a-zA-Z0-9\-_]+\z/
        raise Discourse::InvalidParameters.new(:embed_class)
      end
    end

    response.headers["X-Robots-Tag"] = "noindex, indexifembedded"

    if params.has_key?(:template) && params[:template] == "complete"
      @template = "complete"
    else
      @template = "basic"
    end

    list_options = build_topic_list_options

    if params.has_key?(:per_page)
      list_options[:per_page] = [params[:per_page].to_i, SiteSetting.embed_topic_limit_per_page].min
    end

    if params[:allow_create]
      @allow_create = true
      create_url_params = {}
      create_url_params[:category_id] = params[:category] if params[:category].present?
      create_url_params[:tags] = params[:tags] if params[:tags].present?
      @create_url = "#{Discourse.base_url}/new-topic?#{create_url_params.to_query}"
    end

    topic_query = TopicQuery.new(current_user, list_options)
    top_period = params[:top_period]
    begin
      TopTopic.validate_period(top_period)
      valid_top_period = true
    rescue Discourse::InvalidParameters
      valid_top_period = false
    end

    @list =
      if valid_top_period
        topic_query.list_top_for(top_period)
      else
        topic_query.list_latest
      end
  end

  def comments
    embed_url = params[:embed_url]
    embed_username = params[:discourse_username]
    embed_topic_id = params[:topic_id]&.to_i

    unless embed_topic_id || EmbeddableHost.url_allowed?(embed_url)
      raise Discourse::InvalidAccess.new("invalid embed host")
    end

    if embed_url.present?
      topic_id = TopicEmbed.topic_id_for_embed(embed_url)
    else
      topic_id = params[:topic_id].to_i
    end

    response.headers["X-Robots-Tag"] = "noindex, indexifembedded"
    if topic_id
      @topic_view =
        TopicView.new(
          topic_id,
          current_user,
          limit: SiteSetting.embed_post_limit,
          only_regular: true,
          exclude_first: true,
          exclude_deleted_users: true,
          exclude_hidden: true,
        )
      raise Discourse::NotFound if @topic_view.blank?

      @posts_left = 0
      @second_post_url = "#{@topic_view.topic.url}/2"
      @reply_count = @topic_view.filtered_posts.count - 1
      @reply_count = 0 if @reply_count < 0
      @posts_left = @reply_count - SiteSetting.embed_post_limit if @reply_count >
        SiteSetting.embed_post_limit
    elsif embed_url.present?
      Jobs.enqueue(
        :retrieve_topic,
        user_id: current_user.try(:id),
        embed_url: embed_url,
        author_username: embed_username,
        referer: request.env["HTTP_REFERER"],
      )
      render "loading"
    end

    discourse_expires_in 1.minute
  end

  def info
    embed_url = params.require(:embed_url)
    @topic_embed = TopicEmbed.where(embed_url: embed_url).first

    raise Discourse::NotFound if @topic_embed.nil?

    render_serialized(@topic_embed, TopicEmbedSerializer, root: false)
  end

  def count
    embed_urls = params[:embed_url]
    by_url = {}

    if embed_urls.present?
      urls = embed_urls.map { |u| u.sub(/#discourse-comments\z/, "").sub(%r{/\z}, "") }
      topic_embeds = TopicEmbed.where(embed_url: urls).includes(:topic).references(:topic)

      topic_embeds.each do |te|
        url = te.embed_url
        url = "#{url}#discourse-comments" if params[:embed_url].exclude?(url)
        if te.topic.present?
          by_url[url] = I18n.t("embed.replies", count: te.topic.posts_count - 1)
        else
          by_url[url] = I18n.t("embed.replies", count: 0)
        end
      end
    end

    render json: { counts: by_url }, callback: params[:callback]
  end

  private

  def prepare_embeddable
    response.headers.delete("X-Frame-Options")

    embeddable_host = EmbeddableHost.record_for_url(request.referer)

    @embeddable_css_class =
      if params[:class_name]
        " class=\"#{CGI.escapeHTML(params[:class_name])}\""
      elsif embeddable_host.present? && embeddable_host.class_name.present?
        Discourse.deprecate(
          "class_name field of EmbeddableHost has been deprecated. Prefer passing class_name as a parameter.",
          since: "3.1.0.beta1",
          drop_from: "3.2",
        )

        " class=\"#{CGI.escapeHTML(embeddable_host.class_name)}\""
      else
        ""
      end

    @data_referer =
      if SiteSetting.embed_any_origin? && @data_referer.blank?
        "*"
      else
        request.referer
      end
  end

  def ensure_api_request
    raise Discourse::InvalidAccess.new("api key not set") if !is_api?
  end
end
