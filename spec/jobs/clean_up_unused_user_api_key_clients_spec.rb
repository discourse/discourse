# frozen_string_literal: true

RSpec.describe Jobs::CleanUpUnusedRegisteredUserApiKeyClients do
  let!(:client1) { Fabricate(:user_api_key_client, auth_redirect: "https://remote.com/redirect") }
  let!(:client2) do
    Fabricate(:user_api_key_client, auth_redirect: "https://another-remote.com/redirect")
  end
  let!(:client3) { Fabricate(:user_api_key_client) }
  let!(:key1) { Fabricate(:readonly_user_api_key, client: client1, last_used_at: 1.hour.ago) }
  let!(:key2) { Fabricate(:readonly_user_api_key, client: client1, last_used_at: 1.hour.ago) }
  let!(:key3) { Fabricate(:readonly_user_api_key, client: client2, last_used_at: 1.hour.ago) }
  let!(:key4) { Fabricate(:readonly_user_api_key, client: client3, last_used_at: 1.hour.ago) }

  before do
    SiteSetting.unused_registered_user_api_key_clients_days = 1
    freeze_time
  end

  context "when registered client has used and unused keys" do
    before { key1.update!(last_used_at: 2.days.ago) }

    it "does not destroy client or keys" do
      expect { described_class.new.execute({}) }.to not_change {
        UserApiKeyClient.count
      }.and not_change { UserApiKey.count }
    end
  end

  context "when registered client has only unused keys" do
    before do
      key1.update!(last_used_at: 2.days.ago)
      key2.update!(last_used_at: 2.days.ago)
    end

    it "destroys registered client and associated keys" do
      described_class.new.execute({})
      expect(UserApiKeyClient.exists?(client1.id)).to eq(false)
      expect(UserApiKey.exists?(key1.id)).to eq(false)
      expect(UserApiKey.exists?(key2.id)).to eq(false)
      expect(UserApiKeyClient.exists?(client2.id)).to eq(true)
      expect(UserApiKey.exists?(key3.id)).to eq(true)
      expect(UserApiKeyClient.exists?(client3.id)).to eq(true)
      expect(UserApiKey.exists?(key4.id)).to eq(true)
    end
  end

  context "when unregistered client has only unused keys" do
    before { key4.update!(last_used_at: 2.days.ago) }

    it "does not destroy client or keys" do
      expect { described_class.new.execute({}) }.to not_change {
        UserApiKeyClient.count
      }.and not_change { UserApiKey.count }
    end
  end
end
