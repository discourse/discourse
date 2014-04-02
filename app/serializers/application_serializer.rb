class ApplicationSerializer < ActiveModel::Serializer
  embed :ids

  def filter(keys)
    keys
  end
end
