json.total @total
json.rows do
  json.array! @annotations, partial: 'annotator_store/annotations/annotation', as: :annotation
end
