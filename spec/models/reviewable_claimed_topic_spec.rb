# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewableClaimedTopic, type: :model do

  it "respects the uniqueness constraint" do
    topic = Fabricate(:topic)

    ct = ReviewableClaimedTopic.new(topic_id: topic.id, user_id: Fabricate(:user).id)
    expect(ct.save).to eq(true)

    ct = ReviewableClaimedTopic.new(topic_id: topic.id, user_id: Fabricate(:user).id)
    expect(ct.save).to eq(false)
  end

end
