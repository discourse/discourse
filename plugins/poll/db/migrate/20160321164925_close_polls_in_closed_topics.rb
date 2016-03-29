class ClosePollsInClosedTopics < ActiveRecord::Migration

  def up
    PostCustomField.joins(post: :topic)
                   .where("post_custom_fields.name = 'polls'")
                   .where("topics.closed")
                   .find_each do |pcf|
      polls = ::JSON.parse(pcf.value || "{}")
      polls.values.each { |poll| poll["status"] = "closed" }
      pcf.value = polls.to_json
      pcf.save
    end
  end

  def down
  end

end
