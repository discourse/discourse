class EmbeddableHostSerializer < ApplicationSerializer
  attributes :id, :host, :category_id

  def id
    object.id
  end

  def host
    object.host
  end

  def category_id
    object.category_id
  end
end

