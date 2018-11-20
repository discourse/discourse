class RenameTotalVotesToVoters < ActiveRecord::Migration[4.2]

  def up
    PostCustomField.where(name: "polls").find_each do |pcf|
      polls = ::JSON.parse(pcf.value)
      polls.each_value do |poll|
        next if poll.has_key?("voters")
        poll["voters"] = poll["total_votes"]
        poll.delete("total_votes")
      end
      pcf.value = polls.to_json
      pcf.save
    end
  end

  def down
    PostCustomField.where(name: "polls").find_each do |pcf|
      polls = ::JSON.parse(pcf.value)
      polls.each_value do |poll|
        next if poll.has_key?("total_votes")
        poll["total_votes"] = poll["voters"]
        poll.delete("voters")
      end
      pcf.value = polls.to_json
      pcf.save
    end
  end

end
