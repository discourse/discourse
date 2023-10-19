# frozen_string_literal: true

RSpec.describe UserSecurityKey do
  fab!(:user) { Fabricate(:user) }

  describe "name length validation" do
    it "doesn't allow the name to be longer than the limit" do
      expect do
        Fabricate(
          :user_security_key_with_random_credential,
          user: user,
          name: "b" * (described_class::MAX_NAME_LENGTH + 1),
        )
      end.to raise_error(ActiveRecord::RecordInvalid) do |error|
        expect(error.message).to include(
          I18n.t("activerecord.errors.messages.too_long", count: described_class::MAX_NAME_LENGTH),
        )
      end
    end

    it "allows a name that's under the limit" do
      expect do
        Fabricate(
          :user_security_key_with_random_credential,
          user: user,
          name: "b" * described_class::MAX_NAME_LENGTH,
        )
      end.not_to raise_error
    end
  end

  describe "per-user count validation" do
    it "doesn't allow a user to have more security keys than the limit allows" do
      stub_const(UserSecurityKey, "MAX_KEYS_PER_USER", 1) do
        Fabricate(:user_security_key_with_random_credential, user: user)
        expect do
          Fabricate(:user_security_key_with_random_credential, user: user)
        end.to raise_error(ActiveRecord::RecordInvalid) do |error|
          expect(error.message).to include(I18n.t("login.too_many_security_keys"))
        end
      end
    end

    it "doesn't count security keys from other users" do
      another_user = Fabricate(:user)
      Fabricate(:user_security_key_with_random_credential, user: another_user)

      stub_const(UserSecurityKey, "MAX_KEYS_PER_USER", 1) do
        Fabricate(:user_security_key_with_random_credential, user: user)
        expect do
          Fabricate(:user_security_key_with_random_credential, user: user)
        end.to raise_error(ActiveRecord::RecordInvalid) do |error|
          expect(error.message).to include(I18n.t("login.too_many_security_keys"))
        end
      end
    end
  end
end
