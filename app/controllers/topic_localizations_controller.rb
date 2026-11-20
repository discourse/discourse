# frozen_string_literal: true

class TopicLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def show
    topic = find_visible_topic!

    localization = TopicLocalization.find_by(topic_id: topic.id, locale: params[:locale])
    raise Discourse::NotFound unless localization

    render json: TopicLocalizationSerializer.new(localization, root: false)
  end

  def create_or_update
    locale, title = params.require(%i[locale title])

    topic = find_visible_topic!

    guardian.ensure_can_localize_topic!(topic)

    topic_localization = TopicLocalization.find_by(topic_id: topic.id, locale: params[:locale])
    if topic_localization
      TopicLocalizationUpdater.update(
        topic:,
        locale: params[:locale],
        title: params[:title],
        user: current_user,
      )
      render json: success_json, status: :ok
    else
      TopicLocalizationCreator.create(topic:, locale:, title:, user: current_user)
      render json: success_json, status: :created
    end
  end

  def update_locale
    topic = find_visible_topic!

    updated_topic =
      TopicLocaleUpdater.update(topic:, locale: params.fetch(:locale).presence, user: current_user)
    render json: { locale: updated_topic.locale }, status: :ok
  end

  def destroy
    locale = params.require(:locale)

    topic = find_visible_topic!

    guardian.ensure_can_localize_topic!(topic)

    TopicLocalizationDestroyer.destroy(topic:, locale:, acting_user: current_user)
    head :no_content
  end

  private

  def find_visible_topic!
    topic = Topic.find_by(id: params.require(:topic_id))
    raise Discourse::NotFound unless topic

    begin
      guardian.ensure_can_see!(topic)
    rescue Discourse::InvalidAccess
      raise if SiteSetting.detailed_404

      raise Discourse::NotFound
    end

    topic
  end
end
