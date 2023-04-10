# frozen_string_literal: true

class VoiceCredit < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
end
