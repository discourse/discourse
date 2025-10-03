# frozen_string_literal: true

class Chat::Api::ChannelsArchivesController < Chat::Api::ChannelsController
  def create
    existing_archive = channel_from_params.chat_channel_archive

    if existing_archive.present?
      guardian.ensure_can_change_channel_status!(channel_from_params, :archived)
      raise Discourse::InvalidAccess if !existing_archive.failed?
      Chat::ChannelArchiveService.retry_archive_process(chat_channel: channel_from_params)
      return render json: success_json
    end

    new_topic = archive_params[:type] == "new_topic"
    raise Discourse::InvalidParameters if new_topic && archive_params[:title].blank?
    raise Discourse::InvalidParameters if !new_topic && archive_params[:topic_id].blank?

    if !guardian.can_change_channel_status?(channel_from_params, :read_only)
      raise Discourse::InvalidAccess.new(I18n.t("chat.errors.channel_cannot_be_archived"))
    end

    begin
      Chat::ChannelArchiveService.create_archive_process(
        chat_channel: channel_from_params,
        acting_user: current_user,
        topic_params: topic_params,
      )
    rescue Chat::ChannelArchiveService::ArchiveValidationError => err
      return render json: failed_json.merge(errors: err.errors), status: 400
    end

    render json: success_json
  end

  private

  def archive_params
    @archive_params ||=
      params
        .require(:archive)
        .tap do |ca|
          ca.require(:type)
          ca.permit(:title, :topic_id, :category_id, tags: [])
        end
  end

  def topic_params
    @topic_params ||= {
      topic_id: archive_params[:topic_id],
      topic_title: archive_params[:title],
      category_id: archive_params[:category_id],
      tags: archive_params[:tags],
    }
  end
end
