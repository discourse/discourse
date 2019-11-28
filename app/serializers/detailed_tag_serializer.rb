# frozen_string_literal: true

class DetailedTagSerializer < TagSerializer
  # has_many :synonyms, serializer: TagSerializer, embed: :objects
  # tag_groups, categories

  attributes :synonyms

  def synonyms
    TagsController.tag_counts_json(object.synonyms)
  end
end
