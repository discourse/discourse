# frozen_string_literal: true

describe "PMCreated" do
  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.personal_email_time_window_seconds = 0
    Group.refresh_automatic_groups!
  end

  fab!(:user)
  fab!(:automation) { Fabricate(:automation, trigger: DiscourseAutomation::Triggers::PM_CREATED) }

  context "when creating a PM to a user" do
    fab!(:target_user) { Fabricate(:user) }
    let(:basic_topic_params) do
      {
        title: "hello world topic",
        raw: "my name is fred",
        archetype: Archetype.private_message,
        target_usernames: [target_user.username],
      }
    end

    before do
      automation.upsert_field!(
        "restricted_user",
        "user",
        { value: target_user.username },
        target: "trigger",
      )
    end

    it "fires the trigger" do
      list = capture_contexts { PostCreator.create(user, basic_topic_params) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("pm_created")
    end

    context "when user is not targeted" do
      fab!(:user2) { Fabricate(:user) }

      it "doesn't fire the trigger" do
        list =
          capture_contexts do
            PostCreator.create(
              user,
              basic_topic_params.merge({ target_usernames: [user2.username] }),
            )
          end

        expect(list).to be_blank
      end
    end

    context "when trust_levels are restricted" do
      before do
        automation.upsert_field!(
          "valid_trust_levels",
          "trust-levels",
          { value: [2] },
          target: "trigger",
        )
      end

      context "when trust level is allowed" do
        it "fires the trigger" do
          list =
            capture_contexts do
              user.trust_level = TrustLevel[2]
              user.save!
              PostCreator.create(user, basic_topic_params)
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("pm_created")
        end
      end

      context "when trust level is not allowed" do
        it "doesn’t fire the trigger" do
          list =
            capture_contexts do
              user.trust_level = TrustLevel[1]
              user.save!
              PostCreator.create(user, basic_topic_params)
            end

          expect(list).to be_blank
        end
      end
    end

    context "when staff users ignored" do
      before do
        automation.upsert_field!("ignore_staff", "boolean", { value: true }, target: "trigger")
      end

      it "doesn’t fire the trigger" do
        list =
          capture_contexts do
            user.moderator = true
            user.save!
            PostCreator.create(user, basic_topic_params)
          end

        expect(list).to be_blank
      end
    end
  end

  context "when creating a PM to a group" do
    fab!(:target_group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]) }
    let(:basic_topic_params) do
      {
        title: "hello world topic",
        raw: "my name is fred",
        archetype: Archetype.private_message,
        target_group_names: [target_group.name],
      }
    end

    before do
      automation.upsert_field!(
        "restricted_group",
        "group",
        { value: target_group.id },
        target: "trigger",
      )
    end

    it "fires the trigger" do
      list = capture_contexts { PostCreator.create(user, basic_topic_params) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("pm_created")
    end

    context "when members of the group are ignored" do
      before do
        automation.upsert_field!(
          "ignore_group_members",
          "boolean",
          { value: true },
          target: "trigger",
        )
      end

      it "doesn’t fire the trigger" do
        list =
          capture_contexts do
            user.groups << target_group
            PostCreator.create(user, basic_topic_params)
          end

        expect(list).to be_blank
      end
    end

    context "when the PM is being created from an incoming email" do
      before do
        target_group.update!(
          email_username: "team@somesmtpaddress.com",
          incoming_email: "team@somesmtpaddress.com|suppor+team@bar.com",
          smtp_server: "smtp.test.com",
          smtp_port: 587,
          smtp_ssl_mode: Group.smtp_ssl_modes[:starttls],
          smtp_enabled: true,
        )
        SiteSetting.email_in = true
      end

      it "fires the trigger" do
        list =
          capture_contexts do
            Email::Receiver.new(email("email_to_group_email_username_1")).process!
          end

        expect(list.length).to eq(1)
        expect(list[0]["kind"]).to eq("pm_created")
      end

      context "when the restricted group does not match" do
        before do
          automation.upsert_field!(
            "restricted_group",
            "group",
            { value: Fabricate(:group).id },
            target: "trigger",
          )
        end

        it "doesn’t fire the trigger" do
          list =
            capture_contexts do
              Email::Receiver.new(email("email_to_group_email_username_1")).process!
            end
          expect(list).to be_blank
        end
      end

      context "when the incoming email is automated" do
        before { SiteSetting.block_auto_generated_emails = false }

        it "fires the trigger" do
          list =
            capture_contexts do
              Email::Receiver.new(email("email_to_group_email_username_auto_generated")).process!
            end

          expect(list.length).to eq(1)
          expect(list[0]["kind"]).to eq("pm_created")
        end

        context "when ignore_automated is true" do
          before do
            automation.upsert_field!(
              "ignore_automated",
              "boolean",
              { value: true },
              target: "trigger",
            )
          end

          it "doesn't fire the trigger" do
            list =
              capture_contexts do
                Email::Receiver.new(email("email_to_group_email_username_auto_generated")).process!
              end

            expect(list).to be_blank
          end
        end
      end
    end
  end
end
