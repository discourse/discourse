class AboutSerializer < ApplicationSerializer

  class UserAboutSerializer < BasicUserSerializer
    attributes :title, :last_seen_at
  end

  has_many :moderators, serializer: UserAboutSerializer, embed: :objects
  has_many :admins, serializer: UserAboutSerializer, embed: :objects

  attributes :stats,
             :description,
             :title,
             :locale,
             :version,
             :https

  def stats
    object.class.fetch_cached_stats || Jobs::AboutStats.new.execute({})
  end
end
