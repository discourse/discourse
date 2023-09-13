# frozen_string_literal: true

RSpec.describe UserSecondFactor do
  fab!(:user) { Fabricate(:user) }

  describe ".methods" do
    it "should retain the right order" do
      expect(described_class.methods[:totp]).to eq(1)
      expect(described_class.methods[:backup_codes]).to eq(2)
    end
  end

  describe "name length validation" do
    it "allows the name to be nil" do
      Fabricate(:user_second_factor_totp, user: user, name: nil)
    end

    it "doesn't allow the name to be longer than the limit" do
      expect do
        Fabricate(
          :user_second_factor_totp,
          user: user,
          name: "a" * (described_class::MAX_NAME_LENGTH + 1),
        )
      end.to raise_error(ActiveRecord::RecordInvalid) do |error|
        expect(error.message).to include(
          I18n.t("activerecord.errors.messages.too_long", count: described_class::MAX_NAME_LENGTH),
        )
      end
    end

    it "allows a name that is equal to or less than the limit" do
      expect do
        Fabricate(
          :user_second_factor_totp,
          user: user,
          name: "a" * described_class::MAX_NAME_LENGTH,
        )
      end.not_to raise_error
    end
  end

  describe "per-user count validation" do
    it "doesn't allow a user to have more authenticators than the limit allows" do
      stub_const(UserSecondFactor, "MAX_TOTPS_PER_USER", 1) do
        Fabricate(:user_second_factor_totp, user: user)
        expect do Fabricate(:user_second_factor_totp, user: user) end.to raise_error(
          ActiveRecord::RecordInvalid,
        ) do |error|
          expect(error.message).to include(I18n.t("login.too_many_authenticators"))
        end
      end
    end

    it "doesn't count backup codes in the authenticators limit" do
      user.generate_backup_codes
      expect(user.user_second_factors.backup_codes.count).to eq(10)

      stub_const(UserSecondFactor, "MAX_TOTPS_PER_USER", 1) do
        Fabricate(:user_second_factor_totp, user: user)
        expect do Fabricate(:user_second_factor_totp, user: user) end.to raise_error(
          ActiveRecord::RecordInvalid,
        ) do |error|
          expect(error.message).to include(I18n.t("login.too_many_authenticators"))
        end
      end
    end

    it "doesn't count authenticators from other users" do
      another_user = Fabricate(:user)
      Fabricate(:user_second_factor_totp, user: another_user)

      stub_const(UserSecondFactor, "MAX_TOTPS_PER_USER", 1) do
        Fabricate(:user_second_factor_totp, user: user)
        expect do Fabricate(:user_second_factor_totp, user: user) end.to raise_error(
          ActiveRecord::RecordInvalid,
        ) do |error|
          expect(error.message).to include(I18n.t("login.too_many_authenticators"))
        end
      end
    end
  end
end
