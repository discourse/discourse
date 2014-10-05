class FlaggedTopicSerializer < ActiveModel::Serializer
  attributes :id,
             :title,
             :slug,
             :archived,
             :closed,
             :visible,
             :archetype,
             :relative_url
end
