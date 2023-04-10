# frozen_string_literal: true

class VoiceCredit < ActiveRecord::Base
  belongs_to :user
  belongs_to :topic
  belongs_to :category

  validates_presence_of :user, :topic, :category, :credits_allocated
end
