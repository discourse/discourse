class AboutSerializer < ApplicationSerializer
  has_many :moderators, serializer: BasicUserSerializer, embed: :objects
  has_many :admins, serializer: BasicUserSerializer, embed: :objects

  attributes :stats,
             :description,
             :title,
             :locale,
             :version
end
