# frozen_string_literal: true

module Voice
  module UserExtension
    extend ActiveSupport::Concern

    included do
      # No dependent option: a deleted creator's rooms are reassigned to the
      # system user by the plugin's user_destroyed handler, not destroyed.
      has_many :voice_rooms, class_name: "Voice::Room", foreign_key: :creator_id
    end
  end
end

::User.include Voice::UserExtension
