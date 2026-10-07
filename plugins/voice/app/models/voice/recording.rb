# frozen_string_literal: true

module Voice
  # Durable log of a call recording, one row per LiveKit egress. The Redis
  # recording state dies with the room instance, but the egress_ended webhook
  # — which carries the file's final location — usually arrives after that,
  # so delivery (the requester's PM, the admin listing) needs this row.
  class Recording < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}recordings"

    enum :status, { recording: 0, completed: 1, failed: 2 }

    belongs_to :room, class_name: "Voice::Room"
    belongs_to :started_by, class_name: "User"

    validates :egress_id, presence: true, uniqueness: true
    validates :filepath, presence: true

    # The URL when the egress uploaded to cloud storage, otherwise the path
    # on the recording server's own storage.
    def link_or_path
      location.presence || filepath
    end
  end
end

# == Schema Information
#
# Table name: voice_recordings
#
#  id            :bigint           not null, primary key
#  duration_ms   :bigint
#  ended_at      :datetime
#  filename      :string
#  filepath      :string           not null
#  location      :string
#  size_bytes    :bigint
#  started_at    :datetime         not null
#  status        :integer          default("recording"), not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  egress_id     :string           not null
#  room_id       :bigint           not null
#  started_by_id :bigint           not null
#
# Indexes
#
#  index_voice_recordings_on_egress_id               (egress_id) UNIQUE
#  index_voice_recordings_on_room_id_and_started_at  (room_id,started_at)
#
