class EmbeddableHostSerializer < ApplicationSerializer
  TO_SERIALIZE = %i[id host path_whitelist class_name category_id]

  attributes *TO_SERIALIZE

  TO_SERIALIZE.each { |attr| define_method(attr) { object.send(attr) } }
end
