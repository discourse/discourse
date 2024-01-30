# frozen_string_literal: true

RSpec.describe Jobs::CleanUpUserApiKeysMaxLife do
  fab!(:older_key) { Fabricate(:readonly_user_api_key, created_at: 3.days.ago) }
  fab!(:newer_key) { Fabricate(:readonly_user_api_key, created_at: 1.day.ago) }
  fab!(:revoked_key) do
    Fabricate(:readonly_user_api_key, created_at: 4.day.ago, revoked_at: 1.day.ago)
  end

  context "when user api key was created before the max life period" do
    before { SiteSetting.revoke_user_api_keys_maxlife_days = 2 }

    it "should revoke active keys" do
      freeze_time

      expect { described_class.new.execute({}) }.to change { older_key.reload.revoked_at }.from(
        nil,
      ).to(be_within_one_second_of Time.current).and not_change {
              newer_key.reload.revoked_at
            }.and not_change { revoked_key.reload.revoked_at }
    end
  end
end
