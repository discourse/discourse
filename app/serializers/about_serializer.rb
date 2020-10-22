# frozen_string_literal: true

class AboutSerializer < ApplicationSerializer

  class UserAboutSerializer < BasicUserSerializer
    attributes :title, :last_seen_at
  end

  class AboutCategoryModsSerializer < ApplicationSerializer
    attributes :category_id

    has_many :moderators, serializer: UserAboutSerializer, embed: :objects
  end

  has_many :moderators, serializer: UserAboutSerializer, embed: :objects
  has_many :admins, serializer: UserAboutSerializer, embed: :objects
  has_many :category_moderators, serializer: AboutCategoryModsSerializer, embed: :objects

  attributes :stats,
             :description,
             :title,
             :locale,
             :version,
             :https,
             :can_see_about_stats

  def can_see_about_stats
    scope.can_see_about_stats?
  end

  def include_stats?
    can_see_about_stats
  end

  def stats
    object.class.fetch_cached_stats || Jobs::AboutStats.new.execute({})
  end
end
