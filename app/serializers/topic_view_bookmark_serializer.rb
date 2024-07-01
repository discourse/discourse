# frozen_string_literal: true

class TopicViewBookmarkSerializer < ApplicationSerializer
  attributes :id, :bookmarkable_id, :bookmarkable_type, :reminder_at, :name, :auto_delete_preference
end
