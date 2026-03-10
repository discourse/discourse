# frozen_string_literal: true

RSpec.describe Jobs::BulkRecalculateTrustLevel do
  it "raises an error when user_ids are missing" do
    expect { Jobs::BulkRecalculateTrustLevel.new.execute({}) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "recalculates trust level for each user" do
    user1 = Fabricate(:user, trust_level: 4)
    user2 = Fabricate(:user, trust_level: 4)

    Jobs::BulkRecalculateTrustLevel.new.execute(user_ids: [user1.id, user2.id])

    expect(user1.reload.trust_level).to be <= 4
    expect(user2.reload.trust_level).to be <= 4
  end
end
