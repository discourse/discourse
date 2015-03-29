class AboutSerializer < ApplicationSerializer
  has_many :moderators, serializer: UserNameSerializer, embed: :objects
  has_many :admins, serializer: UserNameSerializer, embed: :objects

  attributes :stats,
             :description,
             :title,
             :locale,
             :version,
             :https
end
