# frozen_string_literal: true

RSpec.describe EmailLoginCode::Redeem do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_presence_of(:code) }
    it { is_expected.not_to allow_values("12345", "abcdef").for(:code) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    let(:params) { { email:, code: } }
    let(:dependencies) { { ip_address: "127.0.0.1" } }
    let(:email) { "newuser@example.com" }

    let!(:login_code) { EmailLoginCode.generate!(email:) }

    let(:code) { login_code.code }

    context "when contract isn't valid" do
      let(:code) { "12345" }

      it { is_expected.to fail_a_contract }
    end

    context "when there is no active code for the email" do
      before { login_code.consume! }

      it { is_expected.to fail_to_find_a_model(:login_code) }
    end

    context "when the code is wrong" do
      let(:code) { login_code.code == "000000" ? "000001" : "000000" }

      it { is_expected.to fail_a_policy(:code_matches) }
    end

    context "when the email is unknown and registrations are disabled" do
      before { SiteSetting.allow_new_registrations = false }

      it { is_expected.to fail_a_policy(:can_register_new_account) }

      it "does not consume the code or create a user" do
        result

        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
      end
    end

    context "when the email domain is blocked" do
      let(:email) { "jane@blocked.com" }

      before { SiteSetting.blocked_email_domains = "blocked.com" }

      it { is_expected.to fail_a_policy(:can_register_new_account) }

      it "does not consume the code or create a user" do
        result

        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
      end
    end

    context "when the email is screened" do
      let(:email) { "jane@example.com" }

      before { Fabricate(:screened_email, email:, action_type: ScreenedEmail.actions[:block]) }

      it { is_expected.to fail_a_policy(:can_register_new_account) }
    end

    context "when the email domain is not in the allowlist" do
      let(:email) { "jane@example.com" }

      before { SiteSetting.allowed_email_domains = "allowed.com" }

      it { is_expected.to fail_a_policy(:can_register_new_account) }
    end

    context "when the email matches an existing account only after normalization" do
      fab!(:other_user) { Fabricate(:user, email: "foobar@example.com") }

      let(:email) { "foo.bar@example.com" }

      before { SiteSetting.normalize_emails = true }

      it { is_expected.to fail_a_policy(:email_available_for_new_account) }

      it "does not consume the code or create a user" do
        result

        expect(login_code.reload.consumed_at).to be_nil
        expect(User.find_by_email(email)).to be_nil
      end
    end

    context "when the email is unknown" do
      let(:email) { "jane@example.com" }

      it { is_expected.to run_successfully }

      it "consumes the code" do
        expect { result }.to change { login_code.reload.consumed_at }.from(nil)
      end

      it "creates an active user with a confirmed email and no password" do
        user = result[:user]

        expect(user).to be_active
        expect(user.email).to eq(email)
        expect(user).to be_email_confirmed
        expect(user.password_hash).to be_nil
        expect(user.registration_ip_address.to_s).to eq("127.0.0.1")
      end

      it "does not derive the username from the email by default" do
        expect(result[:user].username).not_to include("jane")
      end

      it "derives the username from the email when email-based suggestions are enabled" do
        SiteSetting.use_email_for_username_and_name_suggestions = true

        expect(result[:user].username).to eq("jane")
      end

      it "defaults the name to the generated username" do
        user = result[:user]

        expect(user.name).to eq(user.username)
      end

      context "when a name is provided" do
        let(:params) { { email:, code:, name: "Jane Doe" } }

        it "saves the name even though it isn't required" do
          expect(result[:user].name).to eq("Jane Doe")
        end
      end

      it "enqueues the welcome message" do
        expect { result }.to change {
          Jobs::SendSystemMessage.jobs.count do |job|
            job["args"][0]["message_type"] == "welcome_user"
          end
        }.by(1)
      end
    end

    context "when required signup fields exist" do
      fab!(:user_field)

      it { is_expected.to fail_a_policy(:required_fields_provided) }

      it "does not consume the code" do
        result

        expect(login_code.reload.consumed_at).to be_nil
      end

      context "when the field values are provided" do
        let(:params) { { email:, code:, user_fields: { user_field.id.to_s => "Dev" } } }

        it { is_expected.to run_successfully }

        it "saves the field value on the new user" do
          expect(result[:user].custom_fields["user_field_#{user_field.id}"]).to eq("Dev")
        end

        context "when a field is not shown on signup" do
          fab!(:hidden_field) do
            Fabricate(:user_field, requirement: "optional", show_on_signup: false)
          end

          let(:params) do
            {
              email:,
              code:,
              user_fields: {
                user_field.id.to_s => "Dev",
                hidden_field.id.to_s => "Secret",
              },
            }
          end

          it "ignores values for fields that aren't shown on signup" do
            user = result[:user]

            expect(user.custom_fields["user_field_#{user_field.id}"]).to eq("Dev")
            expect(user.custom_fields["user_field_#{hidden_field.id}"]).to be_nil
          end
        end
      end

      context "when a required field is hidden from signup" do
        fab!(:hidden_required_field) do
          Fabricate(:user_field, requirement: "for_all_users", show_on_signup: false)
        end

        let(:params) { { email:, code:, user_fields: { user_field.id.to_s => "Dev" } } }

        it "does not require fields the signup form can't collect" do
          expect(result).to run_successfully
        end
      end

      context "when user_fields is malformed" do
        let(:params) { { email:, code:, user_fields: "not-a-hash" } }

        it "fails as a missing field instead of raising" do
          expect { result }.not_to raise_error
          expect(result).to fail_a_policy(:required_fields_provided)
        end
      end

      context "when the email belongs to an existing user" do
        fab!(:user)

        let(:email) { user.email }

        it { is_expected.to run_successfully }
      end
    end

    context "when a full name is required at signup" do
      before { SiteSetting.full_name_requirement = "required_at_signup" }

      it { is_expected.to fail_a_policy(:required_full_name_provided) }

      it "does not consume the code" do
        result

        expect(login_code.reload.consumed_at).to be_nil
      end

      context "when the name is only whitespace" do
        let(:params) { { email:, code:, name: "   " } }

        it { is_expected.to fail_a_policy(:required_full_name_provided) }
      end

      context "when a name is provided" do
        let(:params) { { email:, code:, name: "Jane Doe" } }

        it { is_expected.to run_successfully }

        it "saves the name on the new user" do
          expect(result[:user].name).to eq("Jane Doe")
        end
      end

      context "when the email belongs to an existing active user" do
        fab!(:user)

        let(:email) { user.email }

        it { is_expected.to run_successfully }
      end
    end

    context "when the email belongs to a staged user" do
      fab!(:staged_user) { Fabricate(:staged, active: false) }

      let(:email) { staged_user.email }

      it { is_expected.to run_successfully }

      it "unstages and activates the existing user" do
        user = result[:user]

        expect(user.id).to eq(staged_user.id)
        expect(user).not_to be_staged
        expect(user).to be_active
        expect(login_code.reload.consumed_at).to be_present
      end
    end

    context "when the email belongs to an existing inactive user" do
      fab!(:inactive_user) { Fabricate(:user, active: false) }

      let(:email) { inactive_user.email }

      it { is_expected.to run_successfully }

      it "activates the user and consumes the code" do
        user = result[:user]

        expect(user.id).to eq(inactive_user.id)
        expect(user.reload).to be_active
        expect(login_code.reload.consumed_at).to be_present
      end
    end

    context "when the email belongs to an existing active user" do
      fab!(:user)

      let(:email) { user.email }

      it { is_expected.to run_successfully }

      it "returns the user and consumes the code" do
        expect(result[:user]).to eq(user)
        expect(login_code.reload.consumed_at).to be_present
      end

      it "does not enqueue another welcome message" do
        expect { result }.not_to change { Jobs::SendSystemMessage.jobs.size }
      end

      it "succeeds even when registrations are disabled" do
        SiteSetting.allow_new_registrations = false

        expect(result).to run_successfully
      end
    end

    context "when users must be approved" do
      before do
        SiteSetting.must_approve_users = true
        Jobs.run_immediately!
      end

      it { is_expected.to run_successfully }

      it "creates an unapproved user with a pending reviewable" do
        user = result[:user]

        expect(user).not_to be_approved
        expect(ReviewableUser.pending.find_by(target: user)).to be_present
      end

      context "when the email domain is auto-approved" do
        before { SiteSetting.auto_approve_email_domains = "example.com" }

        it "creates an approved user" do
          expect(result[:user]).to be_approved
        end
      end
    end

    context "when the new account is awaiting approval" do
      before { SiteSetting.must_approve_users = true }

      it "does not enqueue the welcome message until it can access the forum" do
        expect { result }.not_to change {
          Jobs::SendSystemMessage.jobs.count do |job|
            job["args"][0]["message_type"] == "welcome_user"
          end
        }
      end
    end
  end
end
