require 'rails_helper'

describe TopicViewItem do

  def add(topic_id, ip, user_id=nil)
    skip_redis = true
    TopicViewItem.add(topic_id, ip, user_id, nil, skip_redis)
  end

  it "raises nothing for dupes" do
    add(2, "1.1.1.1")
    add(2, "1.1.1.1", 1)

    TopicViewItem.create!(topic_id: 1, ip_address: "1.1.1.1", viewed_at: 1.day.ago)
    add(1, "1.1.1.1")

    expect(TopicViewItem.count).to eq(3)
  end

  it "increases a users view count" do
    user = Fabricate(:user)

    add(1,  "1.1.1.1", user.id)
    add(1,  "1.1.1.1", user.id)

    user.user_stat.reload
    expect(user.user_stat.topics_entered).to eq(1)
  end

end
