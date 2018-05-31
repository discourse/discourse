require 'rails_helper'

describe User do
  let(:user) { Fabricate(:user) }
  let(:profile_page_url) { "#{Discourse.base_url}/users/#{user.username}" }

  before do
    SiteSetting.queue_jobs = false
    SiteSetting.discourse_narrative_bot_enabled = true
  end

  describe 'when a user is created' do
    it 'should initiate the bot' do
      NotificationEmailer.expects(:process_notification).never

      user

      expected_raw = I18n.t('discourse_narrative_bot.new_user_narrative.hello.message',
        username: user.username, title: SiteSetting.title
      )

      expect(Post.last.raw).to include(expected_raw.chomp)
    end

    describe 'welcome post' do
      context 'disabled' do
        before do
          SiteSetting.disable_discourse_narrative_bot_welcome_post = true
        end

        it 'should not initiate the bot' do
          expect { user }.to_not change { Post.count }
        end
      end

      context 'with title emoji disabled' do
        before do
          SiteSetting.disable_discourse_narrative_bot_welcome_post = false
          SiteSetting.max_emojis_in_title = 0
        end

        it 'initiates the bot' do
          expect { user }.to change { Topic.count }.by(1)

          expect(Topic.last.title).to eq(I18n.t(
            'discourse_narrative_bot.new_user_narrative.hello.title'
          ).gsub(/:robot:/, '').strip)
        end
      end

      context 'enabled' do
        before do
          SiteSetting.disable_discourse_narrative_bot_welcome_post = false
        end

        it 'initiate the bot' do
          expect { user }.to change { Topic.count }.by(1)

          expect(Topic.last.title).to eq(I18n.t(
            'discourse_narrative_bot.new_user_narrative.hello.title'
          ))
        end

        describe "when send welcome message is selected" do
          before do
            SiteSetting.discourse_narrative_bot_welcome_post_type = 'welcome_message'
          end

          it 'should send the right welcome message' do
            expect { user }.to change { Topic.count }.by(1)

            expect(Topic.last.title).to eq(I18n.t(
              "system_messages.welcome_user.subject_template",
              site_name: SiteSetting.title
            ))
          end
        end

        describe 'when welcome message is configured to be delayed' do
          before do
            SiteSetting.discourse_narrative_bot_welcome_post_delay = 100
          end

          it 'should delay the welcome post until user logs in' do
            user

            expect(Jobs::NarrativeInit.jobs.count).to eq(0)
          end
        end
      end
    end

    context 'when user is staged' do
      let(:user) { Fabricate(:user, staged: true) }

      it 'should not initiate the bot' do
        expect { user }.to_not change { Post.count }
      end
    end

    context 'when user is anonymous?' do
      let(:anonymous_user) { Fabricate(:anonymous) }

      it 'should not initiate the bot' do
        SiteSetting.allow_anonymous_posting = true

        expect { anonymous_user }.to_not change { Post.count }
      end
    end

    context "when user's username should be ignored" do
      let(:user) { Fabricate.build(:user) }

      before do
        SiteSetting.discourse_narrative_bot_ignored_usernames = 'discourse|test'
      end

      ['discourse', 'test'].each do |username|
        it 'should not initiate the bot' do
          expect { user.update!(username: username) }.to_not change { Post.count }
        end
      end
    end
  end

  describe 'when a user has been destroyed' do
    it "should clean up plugin's store" do
      DiscourseNarrativeBot::Store.set(user.id, 'test')

      user.destroy!

      expect(DiscourseNarrativeBot::Store.get(user.id)).to eq(nil)
    end
  end
end
