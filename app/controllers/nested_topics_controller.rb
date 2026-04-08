# frozen_string_literal: true

class NestedTopicsController < ApplicationController
  skip_before_action :check_xhr, only: %i[show context]

  before_action :ensure_nested_replies_enabled
  before_action :find_topic_with_topic_view, only: %i[show children context]
  before_action :find_topic, only: %i[pin toggle]
  before_action :ensure_not_pm, only: %i[show children context]

  # GET /n/:slug/:topic_id (HTML + JSON)
  # HTML: preloads initial data into the Ember shell (crawlers redirect to flat view)
  # JSON page 0: includes topic metadata, OP post, sort, and message_bus_last_id
  # JSON page 1+: returns only roots for pagination
  def show
    if spa_boot_request?
      if use_crawler_layout?
        redirect_to "/t/#{params[:slug]}/#{params[:topic_id]}", status: :moved_permanently
        return
      end

      store_preloaded("nested_topic_#{@topic.id}", MultiJson.dump(list_roots_response(page: 0)))
      render "default/empty"
      return
    end

    page = params[:page].to_i.clamp(0, 1000)
    render json: list_roots_response(page: page)
  end

  # GET /n/:slug/:topic_id/children/:post_number
  def children
    NestedTopic::ListChildren.call(
      service_params.deep_merge(
        params: {
          parent_post_number: params[:post_number].to_i,
          sort: validated_sort,
          page: params[:page].to_i.clamp(0, 1000),
          depth: params[:depth].to_i.clamp(1, 100),
        },
        topic_view: @topic_view,
      ),
    ) do
      on_success { |response:| render json: response }
      on_failed_contract { raise Discourse::NotFound }
      on_failure { raise Discourse::NotFound }
    end
  end

  # GET /n/:slug/:topic_id/:post_number (HTML + JSON)
  # HTML: preloads context data into the Ember shell (crawlers redirect to flat view)
  # JSON param: context (integer) -- controls ancestor depth.
  #   nil/absent = windowed ancestor chain capped at max_depth (deep-links, notifications)
  #   0 = no ancestors, target at depth 0 ("Continue this thread")
  def context
    if spa_boot_request?
      if use_crawler_layout?
        redirect_to "/t/#{params[:slug]}/#{params[:topic_id]}/#{params[:post_number]}",
                    status: :moved_permanently
        return
      end

      store_preloaded("nested_topic_#{@topic.id}", MultiJson.dump(show_context_response))
      render "default/empty"
      return
    end

    render json: show_context_response
  end

  # PUT /n/:slug/:topic_id/pin
  def pin
    NestedTopic::TogglePin.call(service_params.deep_merge(params: { topic_id: @topic.id })) do
      on_success { |nested_topic:| render json: { pinned_post_ids: nested_topic.pinned_post_ids } }
      on_failed_contract { raise Discourse::NotFound }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_model_not_found(:post) { raise Discourse::NotFound }
      on_failed_policy(:staff_can_edit) { raise Discourse::InvalidAccess }
      on_failed_policy(:post_is_root) { raise Discourse::InvalidParameters.new(:post_id) }
      on_failed_policy(:within_pin_limit) { raise Discourse::InvalidParameters.new(:post_id) }
      on_failure { raise Discourse::InvalidParameters }
    end
  end

  # PUT /n/:slug/:topic_id/toggle
  def toggle
    NestedTopic::Toggle.call(service_params.deep_merge(params: { topic_id: @topic.id })) do
      on_success { |params:| render json: { is_nested_view: params.enabled } }
      on_failed_contract { raise Discourse::InvalidParameters }
      on_model_not_found(:topic) { raise Discourse::NotFound }
      on_failed_policy(:staff_can_edit) { raise Discourse::InvalidAccess }
      on_failure { raise Discourse::InvalidParameters }
    end
  end

  private

  def list_roots_response(page:)
    result = nil
    NestedTopic::ListRoots.call(
      service_params.deep_merge(
        params: {
          sort: validated_sort,
          page: page,
        },
        topic_view: @topic_view,
      ),
    ) do
      on_success { |response:| result = response }
      on_failed_contract { raise Discourse::NotFound }
      on_failure { raise Discourse::NotFound }
    end
    result
  end

  def show_context_response
    result = nil
    NestedTopic::ShowContext.call(
      service_params.deep_merge(
        params: {
          target_post_number: params[:post_number].to_i,
          sort: validated_sort,
          context_depth: params[:context]&.to_i,
        },
        topic_view: @topic_view,
      ),
    ) do
      on_success { |response:| result = response }
      on_failed_contract { raise Discourse::NotFound }
      on_model_not_found(:target_post) { raise Discourse::NotFound }
      on_failure { raise Discourse::NotFound }
    end
    result
  end

  def ensure_nested_replies_enabled
    raise Discourse::NotFound unless SiteSetting.nested_replies_enabled
  end

  def ensure_not_pm
    if @topic.private_message?
      url = "/t/#{@topic.slug}/#{@topic.id}"
      post_number = params[:post_number].to_i
      url << "/#{post_number}" if post_number > 0
      redirect_to url, status: :found
    end
  end

  def find_topic_with_topic_view
    topic_id = params[:topic_id].to_i
    @topic_view =
      TopicView.new(topic_id, current_user, skip_custom_fields: true, skip_post_loading: true)
    @topic = @topic_view.topic
  end

  def find_topic
    @topic = Topic.find_by(id: params[:topic_id].to_i)
    raise Discourse::NotFound unless @topic
  end

  def validated_sort
    sort = params[:sort].to_s.downcase
    NestedReplies::Sort.valid?(sort) ? sort : SiteSetting.nested_replies_default_sort
  end
end
