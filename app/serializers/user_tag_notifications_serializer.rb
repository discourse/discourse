# frozen_string_literal: true

class UserTagNotificationsSerializer < ApplicationSerializer
  include UserTagNotificationsMixin

  attributes :watched_tags, :watching_first_post_tags, :tracked_tags, :muted_tags, :regular_tags

  def user
    object
  end
end
