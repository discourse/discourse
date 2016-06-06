require_dependency 'composer_messages_finder'

class ComposerMessagesController < ApplicationController

  before_filter :ensure_logged_in

  def index
    finder = ComposerMessagesFinder.new(current_user, params.slice(:composerAction, :topic_id, :post_id))
    json = { composer_messages: [finder.find].compact }

    render_json_dump(json, rest_serializer: true)
  end
end
