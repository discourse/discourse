# frozen_string_literal: true

RSpec.describe Jobs::BootstrapFirstAdmin do
  fab!(:admin)

  it "raises an error when user_id is missing" do
    expect { described_class.new.execute({}) }.to raise_error(Discourse::InvalidParameters)
  end

  it "is a no-op when the user does not exist" do
    expect { described_class.new.execute(user_id: -1) }.to_not raise_error
  end

  it "does nothing when the user is not the singular admin" do
    Fabricate(:admin)

    expect { described_class.new.execute(user_id: admin.id) }.to_not change {
      admin.reload.moderator
    }
    expect(UserHistory.where(action: UserHistory.actions[:grant_moderation]).count).to eq(0)
  end

  it "grants moderation and logs the staff action for a singular admin" do
    described_class.new.execute(user_id: admin.id)

    expect(admin.reload.moderator).to eq(true)
    log = UserHistory.where(action: UserHistory.actions[:grant_moderation]).last
    expect(log.target_user_id).to eq(admin.id)
    expect(log.acting_user_id).to eq(Discourse.system_user.id)
  end
end
