# frozen_string_literal: true

class ComposerMessagesController < ApplicationController

  requires_login

  def index
    finder = ComposerMessagesFinder.new(current_user, params.slice(:composer_action, :topic_id, :post_id))
    json = { composer_messages: [finder.find].compact }

    if params[:topic_id].present?
      topic = Topic.where(id: params[:topic_id]).first
      if guardian.can_see?(topic)
        json[:extras] = { duplicate_lookup: TopicLink.duplicate_lookup(topic) }
      end
    end

    render_json_dump(json, rest_serializer: true)
  end
end
