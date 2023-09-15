# frozen_string_literal: true

RSpec.describe Jobs::CleanUpUnusedUserApiKeys do
  fab!(:key1) { Fabricate(:readonly_user_api_key) }
  fab!(:key2) { Fabricate(:readonly_user_api_key) }
  fab!(:key3) { Fabricate(:readonly_user_api_key, revoked_at: 10.days.ago) }

  context "when user api key is unused in last 1 days" do
    before { SiteSetting.revoke_user_api_keys_unused_days = 1 }

    it "should only revoke keys that are active and unused" do
      freeze_time

      key1.update!(last_used_at: 2.days.ago)
      key3.update!(last_used_at: 2.days.ago)

      expect { described_class.new.execute({}) }.to change { key1.reload.revoked_at }.from(nil).to(
        be_within_one_second_of Time.current
      ).and not_change { key2.reload.revoked_at }.and not_change { key3.reload.revoked_at }
    end
  end
end
