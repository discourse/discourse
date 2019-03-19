require 'rails_helper'

RSpec.describe Jobs::CleanUpInactiveUsers do
  it "should clean up new users that have been inactive" do
    SiteSetting.clean_up_inactive_users_after_days = 0

    user = Fabricate(:user,
      last_seen_at: 5.days.ago,
      trust_level: TrustLevel.levels[:newuser]
    )

    Fabricate(:active_user)

    Fabricate(:post, user: Fabricate(:user,
      trust_level: TrustLevel.levels[:newuser],
      last_seen_at: 5.days.ago
    )).user

    Fabricate(:user,
      trust_level: TrustLevel.levels[:newuser],
      last_seen_at: 2.days.ago
    )

    Fabricate(:user, trust_level: TrustLevel.levels[:basic])

    expect { described_class.new.execute({}) }.to_not change { User.count }

    SiteSetting.clean_up_inactive_users_after_days = 4

    expect { described_class.new.execute({}) }
      .to change { User.count }.by(-1)

    expect(User.exists?(id: user.id)).to eq(false)
  end
end
