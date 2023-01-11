# frozen_string_literal: true

RSpec.describe User do
  let(:user) { Fabricate(:user) }
  let(:profile_page_url) { "#{Discourse.base_url}/users/#{user.username}" }

  def i18n_post_args(extra = {})
    { base_uri: "" }.merge(extra)
  end

  def i18n_t(key, params = {})
    I18n.t(key, i18n_post_args.merge(params))
  end

  before do
    stub_image_size
    Jobs.run_immediately!
    SiteSetting.discourse_narrative_bot_enabled = true
  end

  describe "when a user is created" do
    it "should initiate the bot" do
      NotificationEmailer.expects(:process_notification).never

      user

      expected_raw =
        i18n_t(
          "discourse_narrative_bot.new_user_narrative.hello.message",
          username: user.username,
          title: SiteSetting.title,
        )

      expect(Post.last.raw).to include(expected_raw.chomp)
    end

    describe "welcome post" do
      context "when disabled" do
        before { SiteSetting.disable_discourse_narrative_bot_welcome_post = true }

        it "should not initiate the bot" do
          expect { user }.to_not change { Post.count }
        end
      end

      context "with title emoji disabled" do
        before do
          SiteSetting.disable_discourse_narrative_bot_welcome_post = false
          SiteSetting.max_emojis_in_title = 0
        end

        it "initiates the bot" do
          expect { user }.to change { Topic.count }.by(1)

          expect(Topic.last.title).to eq(
            i18n_t("discourse_narrative_bot.new_user_narrative.hello.title").gsub(
              /:robot:/,
              "",
            ).strip,
          )
        end
      end

      context "when enabled" do
        before { SiteSetting.disable_discourse_narrative_bot_welcome_post = false }

        it "initiate the bot" do
          expect { user }.to change { Topic.count }.by(1)

          expect(Topic.last.title).to eq(
            i18n_t("discourse_narrative_bot.new_user_narrative.hello.title"),
          )
        end

        describe "when send welcome message is selected" do
          before { SiteSetting.discourse_narrative_bot_welcome_post_type = "welcome_message" }

          it "should send the right welcome message" do
            expect { user }.to change { Topic.count }.by(1)

            expect(Topic.last.title).to eq(
              i18n_t("system_messages.welcome_user.subject_template", site_name: SiteSetting.title),
            )
          end
        end

        describe "when welcome message is configured to be delayed" do
          before { SiteSetting.discourse_narrative_bot_welcome_post_delay = 100 }

          it "should delay the welcome post until user logs in" do
            user

            expect(Jobs::NarrativeInit.jobs.count).to eq(0)
          end
        end
      end
    end

    context "when user is staged" do
      let(:user) { Fabricate(:user, staged: true) }

      it "should not initiate the bot" do
        expect { user }.to_not change { Post.count }
      end
    end

    context "when user skipped the new user tips" do
      let(:user) { Fabricate(:user) }

      it "should not initiate the bot" do
        SiteSetting.default_other_skip_new_user_tips = true
        expect { user }.to_not change { Post.count }
      end

      it "should delete the existing PM" do
        user.user_option.skip_new_user_tips = true

        expect { user.user_option.save! }.to change { Topic.count }.by(-1).and not_change {
                UserHistory.count
              }.and change { user.unread_high_priority_notifications }.by(-1).and change {
                            user.notifications.count
                          }.by(-1)
      end
    end

    context "when user is anonymous?" do
      before { SiteSetting.allow_anonymous_posting = true }

      it "should initiate bot for real user only" do
        user = Fabricate(:user, trust_level: 1)
        shadow = AnonymousShadowCreator.get(user)

        expect(TopicAllowedUser.where(user_id: shadow.id).count).to eq(0)
        expect(TopicAllowedUser.where(user_id: user.id).count).to eq(1)
      end
    end

    context "when user's username should be ignored" do
      let(:user) { Fabricate.build(:user) }

      before { SiteSetting.discourse_narrative_bot_ignored_usernames = "discourse|test" }

      %w[discourse test].each do |username|
        it "should not initiate the bot" do
          expect { user.update!(username: username) }.to_not change { Post.count }
        end
      end
    end
  end

  describe "when a user has been destroyed" do
    it "should clean up plugin's store" do
      DiscourseNarrativeBot::Store.set(user.id, "test")

      user.destroy!

      expect(DiscourseNarrativeBot::Store.get(user.id)).to eq(nil)
    end
  end

  describe "#manually_disabled_discobot?" do
    it "returns true if the user manually disabled new user tips" do
      user.user_option.skip_new_user_tips = true

      expect(user.manually_disabled_discobot?).to eq(true)
    end
  end
end
