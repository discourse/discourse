# frozen_string_literal: true

module Voice
  class AdminRecordingsController < ::Admin::AdminController
    requires_plugin "voice"

    PAGE_SIZE = 50

    def index
      recordings =
        Voice::Recording
          .includes(:room, :started_by)
          .order(started_at: :desc)
          .offset(params[:offset].to_i.clamp(0..))
          .limit(PAGE_SIZE + 1)
          .to_a

      has_more = recordings.size > PAGE_SIZE
      recordings = recordings.first(PAGE_SIZE)

      render json: {
               recordings: serialize_data(recordings, Voice::AdminRecordingSerializer, root: false),
               has_more: has_more,
             }
    end
  end
end
