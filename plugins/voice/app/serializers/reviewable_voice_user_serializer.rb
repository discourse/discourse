# frozen_string_literal: true

require_dependency "reviewable_serializer"

class ReviewableVoiceUserSerializer < ReviewableSerializer
  payload_attributes :message, :room_id, :room_name, :room_slug
  attributes :room_url

  def created_from_flag?
    true
  end

  def room_url
    "/voice/r/#{object.payload["room_slug"]}"
  end
end
