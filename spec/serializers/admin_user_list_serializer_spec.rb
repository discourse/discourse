# frozen_string_literal: true

RSpec.describe AdminUserListSerializer do
  fab!(:user)
  fab!(:admin)
  let(:guardian) { Guardian.new(admin) }

  let(:serializer) { AdminUserListSerializer.new(user, scope: guardian, root: false) }

  context "when totp enabled" do
    fab!(:user_totp) { Fabricate(:user_second_factor_totp, user: user) }

    it "returns the right values" do
      json = serializer.as_json

      expect(json[:second_factor_enabled]).to eq(true)
    end
  end

  context "when security keys enabled" do
    fab!(:user_security_key) { Fabricate(:user_security_key, user: user) }

    it "returns the right values" do
      json = serializer.as_json

      expect(json[:second_factor_enabled]).to eq(true)
    end
  end

  describe "emails" do
    subject(:json) do
      described_class.new(
        serialized_user,
        scope: Guardian.new(viewed_by),
        root: false,
        emails_desired: emails_desired,
      ).as_json
    end

    fab!(:admin) { Fabricate(:user, admin: true, email: "admin@email.com") }
    fab!(:moderator) { Fabricate(:user, moderator: true, email: "moderator@email.com") }
    fab!(:user) { Fabricate(:user, email: "user@email.com") }

    let(:serialized_user) { user }
    let(:viewed_by) { user }
    let(:emails_desired) { nil }
    let!(:secondary_emails) do
      %w[first second].map do |name|
        Fabricate(:secondary_email, user: serialized_user, email: "#{name}@email.com")
      end
    end

    context "when an admin views their own account" do
      let(:serialized_user) { admin }
      let(:viewed_by) { admin }

      it "contains the admin's emails" do
        expect(json[:email]).to eq("admin@email.com")
        expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
      end
    end

    context "when a regular user views their own account" do
      it "doesn't include the user's emails" do
        expect(json[:email]).to eq(nil)
        expect(json[:secondary_emails]).to eq(nil)
      end
    end

    context "when a moderator requests a user's emails" do
      let(:viewed_by) { moderator }
      let(:emails_desired) { true }

      it "doesn't return emails when moderators_view_emails is disabled" do
        SiteSetting.moderators_view_emails = false

        expect(json[:email]).to eq(nil)
        expect(json[:secondary_emails]).to eq(nil)
      end

      it "returns emails when moderators_view_emails is enabled" do
        SiteSetting.moderators_view_emails = true

        expect(json[:email]).to eq("user@email.com")
        expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
      end
    end

    context "when an admin requests a user's emails" do
      let(:viewed_by) { admin }
      let(:emails_desired) { true }

      it "returns the emails" do
        expect(json[:email]).to eq("user@email.com")
        expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
      end
    end

    context "when an admin views a staged user" do
      let(:viewed_by) { admin }

      it "returns the user's emails" do
        user.update!(staged: true)

        expect(json[:email]).to eq("user@email.com")
        expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
      end
    end

    context "when a moderator views a staged user" do
      let(:viewed_by) { moderator }

      it "doesn't return the user's emails when moderator email access is disabled" do
        SiteSetting.moderators_view_emails = false
        user.update!(staged: true)

        expect(json[:email]).to eq(nil)
        expect(json[:secondary_emails]).to eq(nil)
      end
    end

    context "when an admin requests a staged user's emails" do
      let(:viewed_by) { admin }
      let(:emails_desired) { true }

      it "returns the user's emails" do
        user.update!(staged: true)

        expect(json[:email]).to eq("user@email.com")
        expect(json[:secondary_emails]).to contain_exactly("first@email.com", "second@email.com")
      end
    end
  end

  describe "#can_be_deleted" do
    it "is not included if the include_can_be_deleted option is not present" do
      json = AdminUserListSerializer.new(user, scope: guardian, root: false).as_json

      expect(json.key?(:can_be_deleted)).to eq(false)
    end

    it "is included if the include_can_be_deleted option is true" do
      json =
        AdminUserListSerializer.new(
          user,
          scope: guardian,
          root: false,
          include_can_be_deleted: true,
        ).as_json

      expect(json[:can_be_deleted]).to eq(true)
    end
  end
end
