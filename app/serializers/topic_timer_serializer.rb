# frozen_string_literal: true

class TopicTimerSerializer < ApplicationSerializer
  attributes :id, :execute_at, :duration_minutes, :based_on_last_post, :status_type, :category_id

  def status_type
    TopicTimer.types[object.status_type]
  end
end
