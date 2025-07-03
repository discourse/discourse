# frozen_string_literal: true

class PostLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def show
    guardian.ensure_can_localize_content!

    params.require(:post_id)

    post = Post.find_by(id: params[:post_id])
    return render json_error(I18n.t("not_found"), status: :not_found) if post.blank?

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
    guardian.ensure_can_localize_content!

    params.require(%i[post_id locale raw])

    localization = PostLocalization.find_by(post_id: params[:post_id], locale: params[:locale])
    if localization
      PostLocalizationUpdater.update(
        post_id: params[:post_id],
        locale: params[:locale],
        raw: params[:raw],
        user: current_user,
      )
      render json: success_json, status: :ok
    else
      PostLocalizationCreator.create(
        post_id: params[:post_id],
        locale: params[:locale],
        raw: params[:raw],
        user: current_user,
      )
      render json: success_json, status: :created
    end
  end

  def destroy
    guardian.ensure_can_localize_content!

    params.require(%i[post_id locale])
    PostLocalizationDestroyer.destroy(
      post_id: params[:post_id],
      locale: params[:locale],
      acting_user: current_user,
    )
    head :no_content
  end
end
