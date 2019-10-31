# frozen_string_literal: true

class TopicPendingPostSerializer < ApplicationSerializer
  root 'topic_pending_post'
  attributes :id, :raw, :created_at

  def raw
    object.payload['raw']
  end

  def include_raw?
    object.payload && object.payload['raw'].present?
  end

end
