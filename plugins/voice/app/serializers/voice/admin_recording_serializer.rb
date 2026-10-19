# frozen_string_literal: true

module Voice
  class AdminRecordingSerializer < ApplicationSerializer
    attributes :id,
               :room_id,
               :room_name,
               :egress_id,
               :status,
               :filepath,
               :filename,
               :location,
               :duration_ms,
               :size_bytes,
               :started_at,
               :ended_at

    has_one :started_by, serializer: BasicUserSerializer, embed: :objects

    def room_name
      object.room&.name
    end
  end
end
