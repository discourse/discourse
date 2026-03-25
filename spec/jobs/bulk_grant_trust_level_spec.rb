# frozen_string_literal: true

RSpec.describe Jobs::BulkGrantTrustLevel do
  it "raises an error when trust_level is missing" do
    expect { Jobs::BulkGrantTrustLevel.new.execute(user_ids: [1, 2]) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "raises an error when user_ids are missing" do
    expect { Jobs::BulkGrantTrustLevel.new.execute(trust_level: 0) }.to raise_error(
      Discourse::InvalidParameters,
    )
  end

  it "does not raise when trust_level is missing but recalculate is true" do
    user = Fabricate(:user, trust_level: 0)
    expect {
      Jobs::BulkGrantTrustLevel.new.execute(user_ids: [user.id], recalculate: true)
    }.not_to raise_error
  end

  it "updates the trust_level" do
    user1 = Fabricate(:user, email: "foo@wat.com", trust_level: 0)
    user2 = Fabricate(:user, email: "foo@bar.com", trust_level: 2)

    Jobs::BulkGrantTrustLevel.new.execute(trust_level: 3, user_ids: [user1.id, user2.id])

    user1.reload
    user2.reload
    expect(user1.trust_level).to eq(3)
    expect(user2.trust_level).to eq(3)
  end

  it "recalculates trust level when recalculate is true" do
    group = Fabricate(:group, grant_trust_level: 3)
    user = Fabricate(:user, trust_level: 3)
    group.bulk_add([user.id])

    group.bulk_remove([user.id])
    Jobs::BulkGrantTrustLevel.new.execute(user_ids: [user.id], recalculate: true)

    expect(user.reload.trust_level).to eq(0)
  end
end
