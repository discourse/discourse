# frozen_string_literal: true

RSpec.describe UserEmail do
  fab!(:user)

  describe "Validations" do
    it "allows only one primary email" do
      expect { Fabricate(:secondary_email, user: user, primary: true) }.to raise_error(
        ActiveRecord::RecordInvalid,
      )
    end

    it "allows multiple secondary emails" do
      Fabricate(:secondary_email, user: user, primary: false)
      Fabricate(:secondary_email, user: user, primary: false)

      expect(user.user_emails.count).to eq 3
    end

    it "does not allow an invalid email" do
      user_email = Fabricate.build(:user_email, user: user, email: "asjdaiosd")
      expect(user_email.valid?).to eq(false)
      expect(user_email.errors.details[:email].first[:error]).to eq(I18n.t("user.email.invalid"))
    end
  end

  describe "normalized_email" do
    it "checks if normalized email is unique" do
      SiteSetting.normalize_emails = true

      user_email = user.user_emails.create(email: "a.b+c@example.com", primary: false)
      expect(user_email.normalized_email).to eq("ab@example.com")
      expect(user_email).to be_valid

      user_email = user.user_emails.create(email: "a.b+d@example.com", primary: false)
      expect(user_email.normalized_email).to eq("ab@example.com")
      expect(user_email).not_to be_valid
    end

    it "does not check uniqueness if email normalization is not enabled" do
      SiteSetting.normalize_emails = false

      user_email = user.user_emails.create(email: "a.b+c@example.com", primary: false)
      expect(user_email.normalized_email).to eq("ab@example.com")
      expect(user_email).to be_valid

      user_email = user.user_emails.create(email: "a.b+d@example.com", primary: false)
      expect(user_email.normalized_email).to eq("ab@example.com")
      expect(user_email).to be_valid
    end
  end

  describe "Indexes" do
    it "allows only one primary email" do
      expect {
        Fabricate.build(:secondary_email, user: user, primary: true).save(validate: false)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "allows multiple secondary emails" do
      Fabricate.build(:secondary_email, user: user, primary: false).save(validate: false)
      Fabricate.build(:secondary_email, user: user, primary: false).save(validate: false)
      expect(user.user_emails.count).to eq 3
    end
  end

  describe ".ensure_consistency!" do
    context "when some users have no primary emails" do
      it "creates primary emails for the users without a primary email" do
        user_with_primary_email = Fabricate(:user)
        user_without_primary_email = Fabricate(:user)
        user_without_any_email = Fabricate(:user)

        user_without_primary_email.primary_email.update_column(:primary, false)
        user_without_any_email.user_emails.delete_all
        original_email_of_user_with_primary_email = user_with_primary_email.primary_email.email

        described_class.ensure_consistency!

        expect(user_without_primary_email.reload.primary_email).to be_present
        expect(user_without_any_email.reload.primary_email).to be_present
        expect(
          user_with_primary_email.reload.primary_email.email,
        ).to eq original_email_of_user_with_primary_email
      end
    end
  end
end
