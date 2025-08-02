# frozen_string_literal: true

class AdminGamificationScoreEventIndexSerializer < ApplicationSerializer
  has_many :events, serializer: AdminGamificationScoreEventSerializer, embed: :objects

  def events
    object[:events]
  end
end
