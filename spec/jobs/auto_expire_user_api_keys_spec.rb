# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::AutoExpireUserApiKeys do
  fab!(:key1) { Fabricate(:readonly_user_api_key) }
  fab!(:key2) { Fabricate(:readonly_user_api_key) }

  context 'when user api key is unused in last 1 days' do

    before do
      SiteSetting.expire_user_api_keys_days = 1
    end

    it 'should revoke the key' do
      freeze_time

      key1.update!(last_used_at: 2.days.ago)

      described_class.new.execute({})

      expect(key1.reload.revoked_at).to be_within(1.second).of(Time.zone.now)
      expect(key2.reload.revoked_at).to eq(nil)
    end
  end
end
