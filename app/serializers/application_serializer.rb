class ApplicationSerializer < ActiveModel::Serializer
  embed :ids, include: true
end
