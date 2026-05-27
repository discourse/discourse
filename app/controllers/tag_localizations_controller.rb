# frozen_string_literal: true

class TagLocalizationsController < ApplicationController
  before_action :ensure_logged_in

  def show
    tag = Tag.find_by(id: params[:id])
    raise Discourse::NotFound unless tag

    guardian.ensure_can_localize_tag!(tag)

    tag_localizations = TagLocalization.where(tag_id: tag.id)

    render json: {
             tag_localizations:
               ActiveModel::ArraySerializer.new(
                 tag_localizations,
                 each_serializer: TagLocalizationSerializer,
                 root: false,
               ).as_json,
           },
           status: :ok
  end

  def create_or_update
    tag_id, locale, name = params.require(%i[tag_id locale name])
    description = params[:description]

    tag = Tag.find_by(id: tag_id)
    raise Discourse::NotFound unless tag

    guardian.ensure_can_localize_tag!(tag)

    localization = TagLocalization.find_by(tag_id:, locale:)
    if localization
      TagLocalizationUpdater.update(tag:, locale:, name:, description:, user: current_user)
      render json: success_json, status: :ok
    else
      TagLocalizationCreator.create(tag:, locale:, name:, description:, user: current_user)
      render json: success_json, status: :created
    end
  end

  def destroy
    tag_id, locale = params.require(%i[tag_id locale])

    tag = Tag.find_by(id: tag_id)
    raise Discourse::NotFound unless tag

    guardian.ensure_can_localize_tag!(tag)

    TagLocalizationDestroyer.destroy(tag:, locale:, acting_user: current_user)
    head :no_content
  end
end
