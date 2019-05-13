# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ReviewableClaimedTopic, type: :model do

  it "ensures uniqueness" do
    claimed = Fabricate(:reviewable_claimed_topic)
    expect(-> {
      ReviewableClaimedTopic.create!(topic_id: claimed.topic_id, user_id: Fabricate(:user).id)
    }).to raise_error(ActiveRecord::RecordNotUnique)
  end

end
