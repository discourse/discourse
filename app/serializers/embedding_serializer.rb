class EmbeddingSerializer < ApplicationSerializer
  attributes :id
  has_many :embeddable_hosts, serializer: EmbeddableHostSerializer, embed: :ids

  def id
    object.id
  end
end
