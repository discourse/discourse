# frozen_string_literal: true

class PostLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def show
    post_id = params[:id] || params[:post_id]
    raise ActionController::ParameterMissing.new(:id) if post_id.blank?

    post = Post.find_by(id: post_id)
    return render_json_error(I18n.t("not_found"), status: :not_found) if post.blank?

    guardian.ensure_can_localize_post!(post)

    post_localizations = PostLocalization.where(post_id: post.id)

    topic_localizations_by_locale = {}
    if post.is_first_post?
      TopicLocalization
        .where(topic_id: post.topic_id)
        .each { |tl| topic_localizations_by_locale[tl.locale] = tl }
    end

    post_localizations.each do |pl|
      pl.define_singleton_method(:topic_localization) { topic_localizations_by_locale[pl.locale] }
    end

    render json: {
             post_localizations:
               ActiveModel::ArraySerializer.new(
                 post_localizations,
                 each_serializer: PostLocalizationSerializer,
                 root: false,
               ).as_json,
           },
           status: :ok
  end

  def create_or_update
    post_id, locale, raw = params.require(%i[post_id locale raw])

    guardian.ensure_can_localize_post!(post_id)

    localization = PostLocalization.find_by(post_id:, locale:)
    if localization
      PostLocalizationUpdater.update(post_id: post_id, locale:, raw:, user: current_user)
      render json: success_json, status: :ok
    else
      PostLocalizationCreator.create(post_id: post_id, locale:, raw:, user: current_user)
      render json: success_json, status: :created
    end
  end

  def destroy
    post_id, locale = params.require(%i[post_id locale])

    guardian.ensure_can_localize_post!(post_id)

    PostLocalizationDestroyer.destroy(post_id:, locale:, acting_user: current_user)
    head :no_content
  end
end
