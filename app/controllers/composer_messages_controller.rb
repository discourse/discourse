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

  def user_not_seen
    usernames = params.require(:usernames)
    users = ComposerMessagesFinder.user_not_seen(usernames)
    user_count = users.count
    warning_message = nil

    if user_count > 0
      message_locale = if user_count == 1
        "education.user_not_seen.single"
      else
        "education.user_not_seen.multiple"
      end
      users.map! { |username| "@#{username}" }
      warning_message = I18n.t(message_locale, username: users.join(", "), time_ago: FreedomPatches::Rails4.time_ago_in_words(SiteSetting.pm_warn_user_last_seen_months_ago.month.ago, true, scope: :'datetime.distance_in_words_verbose'))
    end

    json = { user_count: user_count, warning_message: warning_message }
    render_json_dump(json)
  end
end
