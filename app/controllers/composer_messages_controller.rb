require_dependency 'composer_messages_finder'

class ComposerMessagesController < ApplicationController

  before_filter :ensure_logged_in

  def index
    finder = ComposerMessagesFinder.new(current_user, params.slice(:composerAction, :topic_id, :post_id))
    render_json_dump([finder.find].compact)
  end

end

