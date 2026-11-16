# frozen_string_literal: true

module Live
  class AdminRecordingsController < ::Admin::AdminController
    requires_plugin "live"

    PAGE_SIZE = 50

    def index
      recordings =
        Live::Recording
          .includes(:room, :started_by)
          .order(started_at: :desc)
          .offset(params[:offset].to_i.clamp(0..))
          .limit(PAGE_SIZE + 1)
          .to_a

      has_more = recordings.size > PAGE_SIZE
      recordings = recordings.first(PAGE_SIZE)

      render json: {
               recordings: serialize_data(recordings, Live::AdminRecordingSerializer, root: false),
               has_more: has_more,
               last_webhook_at: Live::Livekit.last_webhook_at&.iso8601,
               webhook_url: "#{Discourse.base_url}/live/livekit/webhook",
             }
    end
  end
end
