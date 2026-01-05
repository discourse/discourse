# frozen_string_literal: true

module Tangyzen
  class GamingSerializer < ApplicationSerializer
    attributes :id,
               :title,
               :description,
               :game_name,
               :genre,
               :platform,
               :developer,
               :publisher,
               :release_date,
               :age_rating,
               :multiplayer,
               :coop,
               :rating,
               :playtime_hours,
               :dlc_available,
               :in_game_purchases,
               :cross_platform,
               :free_to_play,
               :cover_image_url,
               :screenshot_urls,
               :video_url,
               :website_url,
               :status,
               :featured,
               :featured_at,
               :like_count,
               :save_count,
               :view_count,
               :created_at,
               :updated_at

    has_one :user, serializer: BasicUserSerializer, embed: :objects

    def include_user?
      object.user.present?
    end
  end
end
