require 'rails_helper'

RSpec.describe Jobs::AutoExpireUserApiKeys do
  let(:key1) { Fabricate(:readonly_user_api_key) }
  let(:key2) { Fabricate(:readonly_user_api_key) }

  context 'when user api key is unused in last 1 days' do

    before do
      SiteSetting.expire_user_api_keys_days = true
    end

    it 'should revoke the key' do
      freeze_time

      key1.update!(last_used_at: 2.days.ago)

      described_class.new.execute({})

      expect(key1.reload.revoked_at).to eq(Time.zone.now)
      expect(key2.reload.revoked_at).to eq(nil)
    end
  end
end
