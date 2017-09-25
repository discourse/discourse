class MergePollsVotes < ActiveRecord::Migration[4.2]

  def up
    PostCustomField.where(name: "polls").order(:post_id).pluck(:post_id).each do |post_id|
      polls_votes = {}
      PostCustomField.where(post_id: post_id).where("name LIKE 'polls-votes-%'").find_each do |pcf|
        user_id = pcf.name["polls-votes-".size..-1]
        polls_votes["#{user_id}"] = ::JSON.parse(pcf.value || "{}")
      end

      pcf = PostCustomField.find_or_create_by(name: "polls-votes", post_id: post_id)
      pcf.value = ::JSON.parse(pcf.value || "{}").merge(polls_votes).to_json
      pcf.save
    end
  end

  def down
  end

end
