require 'rails_helper'

RSpec.describe DiscourseNarrativeBot::AdvancedUserNarrative do
  let(:discobot_user) { User.find(-2) }
  let(:first_post) { Fabricate(:post, user: discobot_user) }
  let(:user) { Fabricate(:user) }

  let(:topic) do
    Fabricate(:private_message_topic, first_post: first_post,
                                      topic_allowed_users: [
        Fabricate.build(:topic_allowed_user, user: discobot_user),
        Fabricate.build(:topic_allowed_user, user: user),
      ]
    )
  end

  let(:post) { Fabricate(:post, topic: topic, user: user) }
  let(:narrative) { described_class.new }
  let(:other_topic) { Fabricate(:topic) }
  let(:other_post) { Fabricate(:post, topic: other_topic) }
  let(:skip_trigger) { DiscourseNarrativeBot::TrackSelector.skip_trigger }
  let(:reset_trigger) { DiscourseNarrativeBot::TrackSelector.reset_trigger }

  before do
    SiteSetting.queue_jobs = false
    SiteSetting.discourse_narrative_bot_enabled = true
  end

  describe '#notify_timeout' do
    before do
      narrative.set_data(user,
        state: :tutorial_poll,
        topic_id: topic.id,
        last_post_id: post.id
      )
    end

    it 'should create the right message' do
      expect { narrative.notify_timeout(user) }.to change { Post.count }.by(1)

      expect(Post.last.raw).to eq(I18n.t(
        'discourse_narrative_bot.timeout.message',
        username: user.username,
        skip_trigger: skip_trigger,
        reset_trigger: "#{reset_trigger} #{described_class.reset_trigger}",
        base_uri: ''
      ))
    end
  end

  describe '#reset_bot' do
    before do
      narrative.set_data(user, state: :tutorial_images, topic_id: topic.id)
    end

    context 'when trigger is initiated in a PM' do
      let(:user) { Fabricate(:user) }

      let(:topic) do
        topic_allowed_user = Fabricate.build(:topic_allowed_user, user: user)
        bot = Fabricate.build(:topic_allowed_user, user: discobot_user)
        Fabricate(:private_message_topic, topic_allowed_users: [topic_allowed_user, bot])
      end

      let(:post) { Fabricate(:post, topic: topic) }

      it 'should reset the bot' do
        narrative.reset_bot(user, post)

        expected_raw = I18n.t(
          'discourse_narrative_bot.advanced_user_narrative.start_message',
          username: user.username, base_uri: ''
        )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t('discourse_narrative_bot.advanced_user_narrative.edit.instructions', base_uri: '')}
        RAW

        new_post = topic.ordered_posts.last(2).first

        expect(narrative.get_data(user)).to eq("topic_id" => topic.id,
                                               "state" => "tutorial_edit",
                                               "last_post_id" => new_post.id,
                                               "track" => described_class.to_s,
                                               "tutorial_edit" => {
            "post_id" => Post.last.id
          })

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(new_post.topic.id).to eq(topic.id)
      end
    end

    context 'when trigger is not initiated in a PM' do
      it 'should start the new track in a PM' do
        narrative.reset_bot(user, other_post)

        expected_raw = I18n.t(
          'discourse_narrative_bot.advanced_user_narrative.start_message',
          username: user.username, base_uri: ''
        )

        expected_raw = <<~RAW
        #{expected_raw}

        #{I18n.t('discourse_narrative_bot.advanced_user_narrative.edit.instructions', base_uri: '')}
        RAW

        new_post = Topic.last.ordered_posts.last(2).first

        expect(narrative.get_data(user)).to eq(
          "topic_id" => new_post.topic.id,
          "state" => "tutorial_edit",
          "last_post_id" => new_post.id,
          "track" => described_class.to_s,
          "tutorial_edit" => {
            "post_id" => Post.last.id
          }
        )

        expect(new_post.raw).to eq(expected_raw.chomp)
        expect(new_post.topic.id).to_not eq(topic.id)
      end
    end
  end

  describe "#input" do
    context 'edit tutorial' do
      before do
        narrative.set_data(user,
          state: :tutorial_edit,
          topic_id: topic.id,
          track: described_class.to_s,
          tutorial_edit: {
            post_id: first_post.id
          }
        )
      end

      describe 'when post is not in the right topic' do
        it 'should not do anything' do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_edit)
        end
      end

      describe 'when user replies to the post' do
        it 'should create the right reply' do
          post
          narrative.expects(:enqueue_timeout_job).with(user).once

          expect { narrative.input(:reply, user, post: post) }
            .to change { Post.count }.by(1)

          expect(Post.last.raw).to eq(I18n.t(
            'discourse_narrative_bot.advanced_user_narrative.edit.not_found',
            url: first_post.url, base_uri: ''
          ))
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            post.update!(raw: "@#{discobot_user.username} #{skip_trigger.upcase}")
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(I18n.t(
              'discourse_narrative_bot.advanced_user_narrative.delete.instructions', base_uri: '')
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
          end
        end
      end

      describe 'when user edits the right post' do
        let(:post_2) { Fabricate(:post, user: post.user, topic: post.topic) }

        it 'should create the right reply' do
          post_2

          expect do
            PostRevisor.new(post_2).revise!(post_2.user, raw: 'something new')
          end.to change { Post.count }.by(1)

          expected_raw = <<~RAW
          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.edit.reply', base_uri: '')}

          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.delete.instructions', base_uri: '')}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
        end
      end
    end

    context 'delete tutorial' do
      before do
        narrative.set_data(user,
          state: :tutorial_delete,
          topic_id: topic.id,
          track: described_class.to_s
        )
      end

      describe 'when user replies to the topic' do
        it 'should create the right reply' do
          narrative.expects(:enqueue_timeout_job).with(user).once

          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(I18n.t(
            'discourse_narrative_bot.advanced_user_narrative.delete.not_found', base_uri: ''
          ))

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            post.update!(raw: skip_trigger.upcase)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = topic.ordered_posts.last(2).first

            expect(new_post.raw).to eq(I18n.t(
              'discourse_narrative_bot.advanced_user_narrative.recover.instructions', base_uri: '')
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
          end
        end
      end

      describe 'when user destroys a post in a different topic' do
        it 'should not do anything' do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          PostDestroyer.new(user, other_post).destroy

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_delete)
        end
      end

      describe 'when user deletes a post in the right topic' do
        it 'should create the right reply' do
          post

          expect { PostDestroyer.new(user, post).destroy }
            .to change { Post.count }.by(2)

          expected_raw = <<~RAW
          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.delete.reply', base_uri: '')}

          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.recover.instructions', base_uri: '')}
          RAW

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
          expect(topic.ordered_posts.last(2).first.raw).to eq(expected_raw.chomp)
        end

        context 'when user is an admin' do
          it 'should create the right reply' do
            post
            user.update!(admin: true)

            expect { PostDestroyer.new(user, post).destroy }
              .to_not change { Post.count }

            expected_raw = <<~RAW
            #{I18n.t('discourse_narrative_bot.advanced_user_narrative.delete.reply', base_uri: '')}

            #{I18n.t('discourse_narrative_bot.advanced_user_narrative.recover.instructions', base_uri: '')}
            RAW

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
            expect(Post.last.raw).to eq(expected_raw.chomp)
          end
        end
      end
    end

    context 'undelete post tutorial' do
      before do
        narrative.set_data(user,
          state: :tutorial_recover,
          topic_id: topic.id,
          track: described_class.to_s
        )
      end

      describe 'when posts are configured to be deleted immediately' do
        before do
          SiteSetting.delete_removed_posts_after = 0
        end

        it 'should set up the tutorial correctly' do
          narrative.set_data(user,
            state: :tutorial_delete,
            topic_id: topic.id,
            track: described_class.to_s
          )

          PostDestroyer.new(user, post).destroy

          post = Post.last

          expect(post.raw).to eq(I18n.t('js.post.deleted_by_author', count: 1))

          PostDestroyer.destroy_stubs

          expect(post.reload).to be_present
        end
      end

      describe 'when user replies to the topic' do
        it 'should create the right reply' do
          narrative.set_data(user, narrative.get_data(user).merge(
            tutorial_recover: { post_id: '1' }
          ))

          narrative.expects(:enqueue_timeout_job).with(user).once

          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(I18n.t(
            'discourse_narrative_bot.advanced_user_narrative.recover.not_found', base_uri: ''
          ))

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            parent_category = Fabricate(:category, name: 'a')
            _category = Fabricate(:category, parent_category: parent_category, name: 'b')

            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(I18n.t(
              'discourse_narrative_bot.advanced_user_narrative.category_hashtag.instructions',
              category: "#a:b", base_uri: ''
            ))

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
          end
        end
      end

      describe 'when user recovers a post in a different topic' do
        it 'should not do anything' do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          PostDestroyer.new(user, other_post).destroy
          PostDestroyer.new(user, other_post).recover

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_recover)
        end
      end

      describe 'when user recovers a post in the right topic' do
        it 'should create the right reply' do
          parent_category = Fabricate(:category, name: 'a')
          _category = Fabricate(:category, parent_category: parent_category, name: 'b')
          post

          PostDestroyer.new(user, post).destroy

          expect { PostDestroyer.new(user, post).recover }
            .to change { Post.count }.by(1)

          expected_raw = <<~RAW
          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.recover.reply', base_uri: '')}

          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.category_hashtag.instructions', category: "#a:b", base_uri: '')}
          RAW

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
          expect(Post.last.raw).to eq(expected_raw.chomp)
        end
      end
    end

    context 'category hashtag tutorial' do
      before do
        narrative.set_data(user,
          state: :tutorial_category_hashtag,
          topic_id: topic.id,
          track: described_class.to_s
        )
      end

      describe 'when post is not in the right topic' do
        it 'should not do anything' do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }
            .to_not change { Post.count }

          expect(narrative.get_data(user)[:state].to_sym)
            .to eq(:tutorial_category_hashtag)
        end
      end

      describe 'when user replies to the topic' do
        it 'should create the right reply' do
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(I18n.t(
            'discourse_narrative_bot.advanced_user_narrative.category_hashtag.not_found', base_uri: ''
          ))

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_category_hashtag)
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(I18n.t(
              'discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.instructions', base_uri: ''
            ))

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_change_topic_notification_level)
          end
        end
      end

      it 'should create the right reply' do
        category = Fabricate(:category)

        post.update!(raw: "Check out this ##{category.slug}")
        narrative.input(:reply, user, post: post)

        expected_raw = <<~RAW
          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.category_hashtag.reply', base_uri: '')}

          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.instructions', base_uri: '')}
        RAW

        expect(Post.last.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_change_topic_notification_level)
      end
    end

    context 'topic notification level tutorial' do
      before do
        narrative.set_data(user,
          state: :tutorial_change_topic_notification_level,
          topic_id: topic.id,
          track: described_class.to_s
        )
      end

      describe 'when notification level is changed for another topic' do
        it 'should not do anything' do
          other_topic
          user
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect do
            TopicUser.change(
              user.id,
              other_topic.id,
              notification_level: TopicUser.notification_levels[:tracking]
            )
          end.to_not change { Post.count }

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_change_topic_notification_level)
        end
      end

      describe 'when user replies to the topic' do
        it 'should create the right reply' do
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(I18n.t(
            'discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.not_found', base_uri: ''
          ))

          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_change_topic_notification_level)
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(I18n.t(
              'discourse_narrative_bot.advanced_user_narrative.poll.instructions', base_uri: '')
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
          end
        end
      end

      describe 'when user changed the topic notification level' do
        it 'should create the right reply' do
          TopicUser.change(
            user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking]
          )

          expected_raw = <<~RAW
            #{I18n.t('discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.reply', base_uri: '')}

            #{I18n.t('discourse_narrative_bot.advanced_user_narrative.poll.instructions', base_uri: '')}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
        end
      end

      describe 'when poll is disabled' do
        before do
          SiteSetting.poll_enabled = false
        end

        it 'should create the right reply' do
          TopicUser.change(
            user.id,
            topic.id,
            notification_level: TopicUser.notification_levels[:tracking]
          )

          expected_raw = <<~RAW
            #{I18n.t('discourse_narrative_bot.advanced_user_narrative.change_topic_notification_level.reply', base_uri: '')}

            #{I18n.t('discourse_narrative_bot.advanced_user_narrative.details.instructions', base_uri: '')}
          RAW

          expect(Post.last.raw).to eq(expected_raw.chomp)
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end
      end
    end

    context 'poll tutorial' do
      before do
        narrative.set_data(user,
          state: :tutorial_poll,
          topic_id: topic.id,
          track: described_class.to_s
        )
      end

      describe 'when post is not in the right topic' do
        it 'should not do anything' do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
        end
      end

      describe 'when user replies to the topic' do
        it 'should create the right reply' do
          narrative.input(:reply, user, post: post)
          new_post = Post.last

          expect(new_post.raw).to eq(I18n.t('discourse_narrative_bot.advanced_user_narrative.poll.not_found', base_uri: ''))
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_poll)
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            post.update!(raw: skip_trigger)
            described_class.any_instance.expects(:enqueue_timeout_job).with(user)

            DiscourseNarrativeBot::TrackSelector.new(:reply, user, post_id: post.id).select

            new_post = Post.last

            expect(new_post.raw).to eq(I18n.t(
              'discourse_narrative_bot.advanced_user_narrative.details.instructions', base_uri: '')
            )

            expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
          end
        end
      end

      it 'should create the right reply' do
        post.update!(raw: "[poll]\n* 1\n* 2\n[/poll]\n")
        narrative.input(:reply, user, post: post)

        expected_raw = <<~RAW
          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.poll.reply', base_uri: '')}

          #{I18n.t('discourse_narrative_bot.advanced_user_narrative.details.instructions', base_uri: '')}
        RAW

        expect(Post.last.raw).to eq(expected_raw.chomp)
        expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
      end
    end

    context "details tutorial" do
      before do
        narrative.set_data(user,
          state: :tutorial_details,
          topic_id: topic.id,
          track: described_class.to_s
        )
      end

      describe 'when post is not in the right topic' do
        it 'should not do anything' do
          other_post
          narrative.expects(:enqueue_timeout_job).with(user).never

          expect { narrative.input(:reply, user, post: other_post) }.to_not change { Post.count }
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end
      end

      describe 'when user replies to the topic' do
        it 'should create the right reply' do
          narrative.input(:reply, user, post: post)

          expect(Post.last.raw).to eq(I18n.t('discourse_narrative_bot.advanced_user_narrative.details.not_found', base_uri: ''))
          expect(narrative.get_data(user)[:state].to_sym).to eq(:tutorial_details)
        end

        describe 'when reply contains the skip trigger' do
          it 'should create the right reply' do
            post.update!(raw: skip_trigger)

            expect do
              DiscourseNarrativeBot::TrackSelector.new(
                :reply, user, post_id: post.id
              ).select
            end.to change { Post.count }.by(1)

            expect(narrative.get_data(user)[:state].to_sym).to eq(:end)
          end
        end
      end

      it 'should create the right reply' do
        post.update!(raw: "[details=\"This is a test\"]\nwooohoo\n[/details]")
        narrative.input(:reply, user, post: post)

        expect(topic.ordered_posts.last(2).first.raw).to eq(I18n.t(
          'discourse_narrative_bot.advanced_user_narrative.details.reply', base_uri: ''
        ))

        expect(narrative.get_data(user)).to eq("state" => "end",
                                               "topic_id" => topic.id,
                                               "track" => described_class.to_s)

        expect(user.badges.where(name: DiscourseNarrativeBot::AdvancedUserNarrative::BADGE_NAME).exists?)
          .to eq(true)
      end
    end
  end
end
