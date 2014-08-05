require 'spec_helper'

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

    TopicViewItem.count.should == 3
  end

end
