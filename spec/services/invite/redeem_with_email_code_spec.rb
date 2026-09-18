# frozen_string_literal: true

RSpec.describe Invite::RedeemWithEmailCode do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:invite_key) }
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.not_to allow_values("12345", "abcdef").for(:code) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:invite) { Fabricate(:invite, email: "invited@example.com") }

    let(:params) { { invite_key: invite.invite_key, email:, code:, username: } }
    let(:username) { "chosen_username" }
    let(:dependencies) { { ip_address: "127.0.0.1", server_session: {} } }
    let(:email) { invite.email }
    let(:login_code) { EmailLoginCode.generate!(email:) }
    let(:code) { login_code.code }

    context "when the contract isn't valid" do
      let(:code) { "12345" }

      it { is_expected.to fail_a_contract }
    end

    context "when the invite cannot be found" do
      let(:params) { { invite_key: "missing", email:, code:, username: } }

      it { is_expected.to fail_to_find_a_model(:invite) }
    end

    context "when the invite is no longer redeemable" do
      before { invite.update!(expires_at: 1.day.ago) }

      it { is_expected.to fail_to_find_a_model(:invite) }
    end

    context "when the email does not match the email invite" do
      let(:email) { "other@example.com" }

      it { is_expected.to fail_a_policy(:email_can_redeem_invite) }
    end

    context "when the email does not match a domain-scoped invite" do
      fab!(:invite) { Fabricate(:invite, email: nil, domain: "allowed.example") }

      let(:email) { "invited@blocked.example" }

      it { is_expected.to fail_a_policy(:email_can_redeem_invite) }
    end

    context "when there is no active code for the email" do
      before { login_code.consume! }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code was issued for password reset" do
      let(:login_code) { EmailLoginCode.generate!(email:, purpose: :password_reset) }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code is wrong" do
      let(:code) { login_code.code == "000000" ? "000001" : "000000" }

      it { is_expected.to fail_a_policy(:code_matches) }
    end

    context "when the email matches an account only after normalization" do
      fab!(:invite) { Fabricate(:invite, email: nil) }
      fab!(:other_user) { Fabricate(:user, email: "foobar@example.com") }

      let(:email) { "foo.bar@example.com" }

      before { SiteSetting.normalize_emails = true }

      it { is_expected.to fail_a_policy(:email_available_for_new_account) }

      it "does not consume the code or redeem the invite" do
        result

        expect(login_code.reload.consumed_at).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when registrations are disabled for a new account" do
      before { SiteSetting.allow_new_registrations = false }

      it { is_expected.to fail_a_policy(:can_register_new_account) }

      it "does not consume the code or redeem the invite" do
        result

        expect(login_code.reload.consumed_at).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when the email is blocked before redemption" do
      before { SiteSetting.blocked_email_domains = "example.com" }

      it { is_expected.to fail_a_policy(:can_register_new_account) }
    end

    context "when a required signup field is missing" do
      fab!(:user_field)

      it { is_expected.to fail_a_policy(:required_fields_provided) }

      it "does not consume the code" do
        result

        expect(login_code.reload.consumed_at).to be_nil
      end
    end

    context "when required signup fields are provided" do
      fab!(:user_field)

      let(:params) do
        {
          invite_key: invite.invite_key,
          email:,
          code:,
          username:,
          user_fields: {
            user_field.id.to_s => "Engineer",
          },
        }
      end

      it { is_expected.to run_successfully }

      it "saves the field on the invited user" do
        expect(result[:user].custom_fields["user_field_#{user_field.id}"]).to eq("Engineer")
      end
    end

    context "when a full name is required at signup" do
      before { SiteSetting.full_name_requirement = "required_at_signup" }

      it { is_expected.to fail_a_policy(:required_full_name_provided) }

      it "does not consume the code" do
        result

        expect(login_code.reload.consumed_at).to be_nil
      end
    end

    context "when a required full name is provided" do
      let(:params) do
        { invite_key: invite.invite_key, email:, code:, username:, name: "Invited Person" }
      end

      before { SiteSetting.full_name_requirement = "required_at_signup" }

      it { is_expected.to run_successfully }

      it "saves the full name" do
        expect(result[:user].name).to eq("Invited Person")
      end
    end

    context "when the username is missing" do
      before { params.delete(:username) }

      it "requires a username without consuming the code or creating an account" do
        expect(result).to fail_a_policy(:required_username_provided)
        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when the username is only whitespace" do
      let(:username) { "   " }

      it "requires a username without consuming the code or creating an account" do
        expect(result).to fail_a_policy(:required_username_provided)
        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when the username is reserved" do
      let(:username) { "reserved_name" }

      before { SiteSetting.reserved_usernames = "reserved_name" }

      it "rejects the username without consuming the code or creating an account" do
        expect(result).to fail_a_policy(:username_allowed)
        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when the username conflicts with a route" do
      let(:username) { "ACCOUNT-CREATED" }

      it "rejects the username without consuming the code or redeeming the invite" do
        expect(result).to fail_a_policy(:username_allowed)
        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when the username has surrounding whitespace" do
      let(:username) { "  chosen_username  " }

      it "creates the account with the trimmed username" do
        expect(result).to run_successfully
        expect(result[:user].username).to eq(username.strip)
      end
    end

    context "when the username is invalid" do
      let(:username) { "invalid username" }

      it "rejects the username without consuming the code or creating an account" do
        expect(result).to fail_to_find_a_model(:user)
        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when the username is already taken" do
      fab!(:other_user) { Fabricate(:user, username: "taken_username") }

      let(:username) { "taken_username" }

      it "rejects the username without consuming the code or creating an account" do
        expect(result).to fail_to_find_a_model(:user)
        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when a staged user chooses an invalid username" do
      fab!(:staged_user) { Fabricate(:staged, email: "invited@example.com", active: false) }

      let(:email) { staged_user.email }
      let(:username) { "invalid username" }

      it "preserves the staged account and code for another attempt" do
        expect { result }.to not_change { staged_user.reload.username }.and(
          not_change { staged_user.reload.staged },
        )
        expect(result).to fail_to_find_a_model(:user)
        expect(staged_user.reload).not_to be_active
        expect(login_code.reload.consumed_at).to be_nil
        expect(invite.reload.redemption_count).to eq(0)
      end
    end

    context "when a new user redeems the invite" do
      it { is_expected.to run_successfully }

      it "consumes the code and redeems the invite" do
        expect { result }.to change { login_code.reload.consumed_at }.from(nil).and(
          change { invite.reload.redemption_count }.from(0).to(1),
        )
      end

      it "creates an active passwordless user with a confirmed email" do
        user = result[:user]

        expect(user).to be_active
        expect(user).to be_email_confirmed
        expect(user.email).to eq(email)
        expect(user.username).to eq(username)
        expect(user.user_password).to be_nil
        expect(user.registration_ip_address.to_s).to eq(dependencies[:ip_address])
      end

      it "does not enqueue password instructions or an activation email" do
        expect { result }.to not_change { Jobs::InvitePasswordInstructionsEmail.jobs.size }.and(
          not_change { Jobs::CriticalUserEmail.jobs.size },
        )
      end
    end

    context "when an existing user redeems the invite" do
      fab!(:existing_user) { Fabricate(:user, email: "invited@example.com") }

      let(:username) { nil }

      it "ignores a supplied username when redeeming for an existing user" do
        params[:username] = "replacement_name"

        expect { result }.not_to change { existing_user.reload.username }
        expect(result).to run_successfully
      end

      it { is_expected.to run_successfully }

      it "returns the existing user and consumes the code" do
        expect(result[:user]).to eq(existing_user)
        expect(result[:existing_user]).to eq(existing_user)
        expect(login_code.reload.consumed_at).to be_present
      end

      it "redeems the invite even when registrations are disabled" do
        SiteSetting.allow_new_registrations = false

        expect(result).to run_successfully
        expect(invite.reload).to be_redeemed
      end
    end

    context "when an invite grants group membership" do
      fab!(:group)

      before do
        group.add_owner(invite.invited_by)
        Fabricate(:invited_group, invite:, group:)
      end

      it "adds the invited user to the group" do
        expect(result[:user].reload.groups).to include(group)
      end
    end

    context "when an invite grants access to a topic" do
      fab!(:topic)

      before { invite.update!(topics: [topic]) }

      it "creates the invited-to-topic notification" do
        result

        expect(
          Notification.exists?(
            user: result[:user],
            topic:,
            notification_type: Notification.types[:invited_to_topic],
          ),
        ).to eq(true)
      end
    end

    context "when users must be approved" do
      before do
        SiteSetting.must_approve_users = true
        Jobs.run_immediately!
      end

      it { is_expected.to run_successfully }

      it "creates an active unapproved user pending review" do
        user = result[:user]

        expect(user).to be_active
        expect(user).not_to be_approved
        expect(ReviewableUser.pending.find_by(target: user)).to be_present
      end
    end
  end
end
