# frozen_string_literal: true

class ReviewableNoteSerializer < ApplicationSerializer
  attributes :id, :content, :cooked, :created_at, :updated_at

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def cooked
    PlaintextMentions.new(object.content).render(
      known_usernames: @options[:reviewable_note_mention_usernames],
    )
  end
end
