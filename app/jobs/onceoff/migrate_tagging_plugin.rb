module Jobs

  class MigrateTaggingPlugin < Jobs::Onceoff

    def execute_onceoff(args)
      all_tags = TopicCustomField.where(name: "tags").select('DISTINCT value').all.map(&:value)
      tag_id_lookup = Tag.create(all_tags.map { |tag_name| {name: tag_name} }).inject({}) { |h,v| h[v.name] = v.id; h }

      TopicCustomField.where(name: "tags").find_each do |tcf|
        TopicTag.create(topic_id: tcf.topic_id, tag_id: tag_id_lookup[tcf.value] || Tag.find_by_name(tcf.value).try(:id))
      end
    end

  end

end
