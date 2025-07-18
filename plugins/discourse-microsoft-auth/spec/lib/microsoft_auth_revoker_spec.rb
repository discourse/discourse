# frozen_string_literal: true

require_relative "../../lib/microsoft_auth_revoker"

RSpec.describe MicrosoftAuthRevoker do
  describe ".revoke" do
    fab!(:user_1) { Fabricate(:user).tap { |user| UserAuthToken.generate!(user_id: user.id) } }
    fab!(:user_2) { Fabricate(:user).tap { |user| UserAuthToken.generate!(user_id: user.id) } }
    fab!(:user_3) { Fabricate(:user).tap { |user| UserAuthToken.generate!(user_id: user.id) } }

    fab!(:microsoft_user_associated_account_for_user_1) do
      UserAssociatedAccount.create!(
        provider_name: "microsoft_office365",
        user_id: user_1.id,
        provider_uid: 100,
        info: {
          email: "someuser@somedomain.tld",
        },
      )
    end

    fab!(:microsoft_user_associated_account_for_user_2) do
      UserAssociatedAccount.create!(
        provider_name: "microsoft_office365",
        user_id: user_2.id,
        provider_uid: 200,
        info: {
          email: "someuser@somedomain.tld",
        },
      )
    end

    fab!(:facebook_user_associated_account_for_user_3) do
      UserAssociatedAccount.create!(
        provider_name: "facebook",
        user_id: user_1.id,
        provider_uid: 100,
        info: {
          email: "someuser@somedomain.tld",
        },
      )
    end

    fab!(:user_api_key_for_user_1) { Fabricate(:user_api_key, user: user_1) }
    fab!(:user_api_key_for_user_2) { Fabricate(:user_api_key, user: user_2) }
    fab!(:user_api_key_for_user_3) { Fabricate(:user_api_key, user: user_3) }
    fab!(:api_key_for_user_1) { Fabricate(:api_key, created_by_id: user_1.id) }
    fab!(:api_key_for_user_2) { Fabricate(:api_key, created_by_id: user_2.id) }
    fab!(:api_key_for_user_3) { Fabricate(:api_key, created_by_id: user_3.id) }

    it "should delete all microsoft provider `UserAssociatedAccount` records" do
      expect do MicrosoftAuthRevoker.revoke end.to change { UserAssociatedAccount.count }.by(-2)
      expect(UserAssociatedAccount.where(provider_name: "microsoft_office365").count).to eq(0)
    end

    it "should deactivate all users with microsoft provider `UserAssociatedAccount` records" do
      expect do MicrosoftAuthRevoker.revoke end.to change { User.where(active: true).count }.by(-2)
      expect(user_1.reload.active).to eq(false)
      expect(user_2.reload.active).to eq(false)
      expect(user_3.reload.active).to eq(true)
    end

    it "should delete all `UserAuthToken` records for users with microsoft provider `UserAssociatedAccount` records" do
      expect do MicrosoftAuthRevoker.revoke end.to change { UserAuthToken.count }.by(-2)
      expect(UserAuthToken.where(user_id: user_1.id).count).to eq(0)
      expect(UserAuthToken.where(user_id: user_2.id).count).to eq(0)
      expect(UserAuthToken.where(user_id: user_3.id).count).to eq(1)
    end

    it "should revoke all `UserApiKey` records for users with microsoft provider `UserAssociatedAccount` records" do
      expect do MicrosoftAuthRevoker.revoke end.to change {
        UserApiKey.where(revoked_at: nil).count
      }.by(-2)

      expect(user_api_key_for_user_1.reload.revoked_at).to be_present
      expect(user_api_key_for_user_2.reload.revoked_at).to be_present
      expect(user_api_key_for_user_3.reload.revoked_at).to be_nil
    end

    it "should revoke all `ApiKey` records created by users with microsoft provider `UserAssociatedAccount` records" do
      expect do MicrosoftAuthRevoker.revoke end.to change {
        ApiKey.where(revoked_at: nil).count
      }.by(-2)

      expect(api_key_for_user_1.reload.revoked_at).to be_present
      expect(api_key_for_user_2.reload.revoked_at).to be_present
      expect(api_key_for_user_3.reload.revoked_at).to be_nil
    end
  end
end
