desc "Add the topic to quotes"
task "add_topic_to_quotes" => :environment do
  Post.where("raw like '%topic:%'").each do |p|
    new_raw = p.raw.gsub(/topic:(\d+)\]/, "topic:#{p.topic_id}\"]")
    new_cooked = p.cook(new_raw, topic_id: p.topic_id)
    Post.update_all ["raw = ?, cooked = ?", new_raw, new_cooked], ["id = ?", p.id]
  end
end

