# frozen_string_literal: true

RSpec.describe Jobs::CleanUpUserApiKeysMaxLife do
  fab!(:older_key) { Fabricate(:readonly_user_api_key, created_at: 3.days.ago) }
  fab!(:newer_key) { Fabricate(:readonly_user_api_key, created_at: 1.day.ago) }

  context "when user api key was created before the max life period" do
    before { SiteSetting.revoke_user_api_keys_maxlife_days = 2 }

    it "should revoke the key" do
      freeze_time

      described_class.new.execute({})

      expect(older_key.reload.revoked_at).to eq_time(Time.zone.now)
      expect(newer_key.reload.revoked_at).to eq(nil)
    end
  end
end
