# frozen_string_literal: true

RSpec.describe Jobs::BulkRecalculateTrustLevel do
  it "raises an error when user_ids are missing" do
    expect { Jobs::BulkRecalculateTrustLevel.new.execute({}) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "calls Promotion.recalculate for each user" do
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    Promotion.expects(:recalculate).with(user1, use_previous_trust_level: true).once
    Promotion.expects(:recalculate).with(user2, use_previous_trust_level: true).once

    Jobs::BulkRecalculateTrustLevel.new.execute(user_ids: [user1.id, user2.id])
  end
end
