# frozen_string_literal: true

class PublishedPagesController < ApplicationController

  skip_before_action :preload_json
  skip_before_action :check_xhr, :verify_authenticity_token, only: [:show]
  before_action :ensure_publish_enabled

  def show
    params.require(:slug)

    pp = PublishedPage.find_by(slug: params[:slug])
    raise Discourse::NotFound unless pp

    guardian.ensure_can_see!(pp.topic)
    @topic = pp.topic
    @canonical_url = @topic.url
    render layout: 'publish'
  end

  def details
    pp = PublishedPage.find_by(topic: fetch_topic)
    raise Discourse::NotFound if pp.blank?
    render_serialized(pp, PublishedPageSerializer)
  end

  def upsert
    result, pp = PublishedPage.publish!(current_user, fetch_topic, params[:published_page][:slug].strip)
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
    raise Discourse::NotFound unless SiteSetting.enable_page_publishing?
  end

end
