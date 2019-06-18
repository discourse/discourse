# frozen_string_literal: true

class ClosePollsInClosedTopics < ActiveRecord::Migration[4.2]

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
