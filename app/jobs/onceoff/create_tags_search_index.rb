module Jobs
  class CreateTagsSearchIndex < Jobs::Onceoff
    def execute_onceoff(args)
      Tag.exec_sql('select id, name from tags').each do |t|
        SearchIndexer.update_tags_index(t['id'], t['name'])
      end
    end
  end
end
