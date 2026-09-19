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

  describe ".normalize" do
    it "removes dots from the local part and everything between + and @" do
      expect(UserEmail.normalize("a.b+c@example.com")).to eq("ab@example.com")
      expect(UserEmail.normalize("a.b@example.com")).to eq("ab@example.com")
      expect(UserEmail.normalize("ab@example.com")).to eq("ab@example.com")
    end

    it "keeps dots in the domain" do
      expect(UserEmail.normalize("a.b@mail.example.com")).to eq("ab@mail.example.com")
    end

    it "returns nil when there is no local part or domain" do
      expect(UserEmail.normalize("a.b")).to be_nil
      expect(UserEmail.normalize("@example.com")).to be_nil
      expect(UserEmail.normalize("")).to be_nil
      expect(UserEmail.normalize(nil)).to be_nil
    end
  end

  describe ".find_by_normalized" do
    it "finds an email whose normalized form matches" do
      user_email = user.user_emails.create!(email: "a.b@example.com", primary: false)

      expect(UserEmail.find_by_normalized("a.b+c@example.com")).to eq(user_email)
      expect(UserEmail.find_by_normalized("A.B@example.com")).to eq(user_email)
      expect(UserEmail.find_by_normalized("ac@example.com")).to be_nil
    end

    it "does not match rows without a normalized email" do
      user.user_emails.update_all(normalized_email: nil)

      expect(UserEmail.find_by_normalized("a.b")).to be_nil
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

    it "allows updating an email to a variant with the same normalized value" do
      SiteSetting.normalize_emails = true

      user_email = user.user_emails.create!(email: "a.b+c@example.com", primary: false)
      expect(user_email.normalized_email).to eq("ab@example.com")

      user_email.email = "a.b@example.com"
      expect(user_email).to be_valid
      expect(user_email.save).to eq(true)
      expect(user_email.reload.email).to eq("a.b@example.com")
    end

    it "blocks updating to an email that normalizes to another user's email" do
      SiteSetting.normalize_emails = true

      other_user = Fabricate(:user)
      other_user.user_emails.create!(email: "taken+alias@example.com", primary: false)

      user_email = user.user_emails.create!(email: "available@example.com", primary: false)
      user_email.email = "taken@example.com"
      expect(user_email).not_to be_valid
      expect(user_email.errors[:email]).to include(I18n.t("errors.messages.taken"))
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
