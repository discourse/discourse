# frozen_string_literal: true

class UserBadgesSerializer < ApplicationSerializer
  root 'user_badges'

  has_many :user_badges, embed: :objects
  attributes :grant_count, :username
end
