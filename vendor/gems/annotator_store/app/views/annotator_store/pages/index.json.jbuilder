json.name 'Annotator Store API'
json.version '2.0.0'
json.links do
  json.annotation do
    json.create do
      json.url annotator_store.annotations_url
      json.method 'POST'
      json.description 'Create or add new annotations.'
    end
    json.read do
      json.url annotator_store.annotation_url(':id')
      json.method 'GET'
      json.description 'Read, retrieve or view existing annotation.'
    end
    json.update do
      json.url annotator_store.annotation_url(':id')
      json.method 'PUT/PATCH'
      json.description 'Update or edit existing annotation.'
    end
    json.delete do
      json.url annotator_store.annotation_url(':id')
      json.method 'DELETE'
      json.description 'Delete or deactivate existing annotation.'
    end
  end
  json.search do
    json.url annotator_store.search_url
    json.method 'GET'
    json.description 'Search for annotations'
  end
end
