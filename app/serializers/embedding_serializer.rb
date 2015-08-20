class EmbeddingSerializer < ApplicationSerializer
  attributes :id, :fields, :base_url
  attributes *Embedding.settings

  has_many :embeddable_hosts, serializer: EmbeddableHostSerializer, embed: :ids

  def fields
    Embedding.settings
  end

  def read_attribute_for_serialization(attr)
    object.respond_to?(attr) ? object.send(attr) : send(attr)
  end
end
