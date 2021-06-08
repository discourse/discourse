# frozen_string_literal: true

require 'rails_helper'

describe ::Presence::PresencesController do
  describe '#handle_message' do
    context 'when not logged in' do
      it 'should raise the right error' do
        post '/presence/publish.json'

        expect(response.status).to eq(403)
      end
    end

    context 'when logged in' do
      fab!(:user) { Fabricate(:user) }
      fab!(:user2) { Fabricate(:user) }
      fab!(:admin) { Fabricate(:admin) }

      fab!(:group) do
        group = Fabricate(:group)
        group.add(user)
        group
      end

      fab!(:category) { Fabricate(:private_category, group: group) }
      fab!(:private_topic) { Fabricate(:topic, category: category) }
      fab!(:public_topic) { Fabricate(:topic, first_post: Fabricate(:post)) }

      fab!(:private_message) do
        Fabricate(:private_message_topic,
          allowed_groups: [group]
        )
      end

      before do
        sign_in(user)
      end

      it 'returns the right response when user disables the presence feature' do
        user.user_option.update_column(:hide_profile_and_presence, true)

        post '/presence/publish.json'

        expect(response.status).to eq(404)
      end

      it 'returns the right response when user disables the presence feature and allow_users_to_hide_profile is disabled' do
        user.user_option.update_column(:hide_profile_and_presence, true)
        SiteSetting.allow_users_to_hide_profile = false

        post '/presence/publish.json', params: { topic_id: public_topic.id, state: 'replying' }

        expect(response.status).to eq(200)
      end

      it 'returns the right response when the presence site settings is disabled' do
        SiteSetting.presence_enabled = false

        post '/presence/publish.json'

        expect(response.status).to eq(404)
      end

      it 'returns the right response if required params are missing' do
        post '/presence/publish.json'

        expect(response.status).to eq(400)
      end

      it 'returns the right response if topic_id is invalid' do
        post '/presence/publish.json', params: { topic_id: -999, state: 'replying' }

        expect(response.status).to eq(400)
      end

      it 'returns the right response when user does not have access to the topic' do
        group.remove(user)

        post '/presence/publish.json', params: { topic_id: private_topic.id, state: 'replying' }

        expect(response.status).to eq(403)
      end

      it 'returns the right response when an invalid state is provided with a post_id' do
        post '/presence/publish.json', params: {
          topic_id: public_topic.id,
          post_id: public_topic.first_post.id,
          state: 'some state'
        }

        expect(response.status).to eq(400)
      end

      it 'returns the right response when user can not edit a post' do
        Fabricate(:post, topic: private_topic, user: private_topic.user)

        post '/presence/publish.json', params: {
          topic_id: private_topic.id,
          post_id: private_topic.first_post.id,
          state: 'editing'
        }

        expect(response.status).to eq(403)
      end

      it 'returns the right response when an invalid post_id is given' do
        post '/presence/publish.json', params: {
          topic_id: public_topic.id,
          post_id: -9,
          state: 'editing'
        }

        expect(response.status).to eq(400)
      end

      it 'publishes the right message for a public topic' do
        freeze_time

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: { topic_id: public_topic.id, state: 'replying' }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.channel).to eq("/presence/#{public_topic.id}")
        expect(message.data.dig(:user, :id)).to eq(user.id)
        expect(message.data[:published_at]).to eq(Time.zone.now.to_i)
        expect(message.group_ids).to eq(nil)
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the right message for a restricted topic' do
        freeze_time

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: private_topic.id,
            state: 'replying'
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.channel).to eq("/presence/#{private_topic.id}")
        expect(message.data.dig(:user, :id)).to eq(user.id)
        expect(message.data[:published_at]).to eq(Time.zone.now.to_i)
        expect(message.group_ids).to contain_exactly(group.id)
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the right message for a private message' do
        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: private_message.id,
            state: 'replying'
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(
          group.id,
          Group::AUTO_GROUPS[:staff]
        )

        expect(message.user_ids).to contain_exactly(
          *private_message.topic_allowed_users.pluck(:user_id)
        )
      end

      it 'publishes the message to staff group when user is whispering' do
        SiteSetting.enable_whispers = true

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            state: 'replying',
            is_whisper: true
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the message to staff group when staff_only param override is present' do
        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            state: 'replying',
            staff_only: true
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the message to staff group when a staff is editing a whisper' do
        SiteSetting.enable_whispers = true
        sign_in(admin)

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            post_id: public_topic.first_post.id,
            state: 'editing',
            is_whisper: true
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the message to staff group when a staff is editing a locked post' do
        SiteSetting.enable_whispers = true
        sign_in(admin)
        locked_post = Fabricate(:post, topic: public_topic, locked_by_id: admin.id)

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            post_id: locked_post.id,
            state: 'editing',
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the message to author, staff group and TL4 group when editing a public post' do
        post = Fabricate(:post, topic: public_topic, user: user)

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            post_id: post.id,
            state: 'editing',
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(
          Group::AUTO_GROUPS[:trust_level_4],
          Group::AUTO_GROUPS[:staff]
        )

        expect(message.user_ids).to contain_exactly(user.id)
      end

      it 'publishes the message to author and staff group when editing a public post ' \
        'if SiteSettings.trusted_users_can_edit_others is set to false' do

        post = Fabricate(:post, topic: public_topic, user: user)
        SiteSetting.trusted_users_can_edit_others = false

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            post_id: post.id,
            state: 'editing',
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(Group::AUTO_GROUPS[:staff])
        expect(message.user_ids).to contain_exactly(user.id)
      end

      it 'publishes the message to SiteSetting.min_trust_to_edit_wiki_post group ' \
        'and staff group when editing a wiki in a public topic' do

        post = Fabricate(:post, topic: public_topic, user: user, wiki: true)
        SiteSetting.min_trust_to_edit_wiki_post = TrustLevel.levels[:basic]

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            post_id: post.id,
            state: 'editing',
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(
          Group::AUTO_GROUPS[:trust_level_1],
          Group::AUTO_GROUPS[:staff]
        )

        expect(message.user_ids).to contain_exactly(user.id)
      end

      it 'publishes the message to author and staff group when editing a private message' do
        post = Fabricate(:post, topic: private_message, user: user)

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: private_message.id,
            post_id: post.id,
            state: 'editing',
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(
          Group::AUTO_GROUPS[:staff],
        )

        expect(message.user_ids).to contain_exactly(user.id)
      end

      it 'publishes the message to users with trust levels of SiteSetting.min_trust_to_edit_wiki_post ' \
        'and staff group when editing a wiki in a private message' do

        post = Fabricate(:post,
          topic: private_message,
          user: private_message.user,
          wiki: true
        )

        user2.update!(trust_level: TrustLevel.levels[:newuser])
        group.add(user2)

        SiteSetting.min_trust_to_edit_wiki_post = TrustLevel.levels[:basic]

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: private_message.id,
            post_id: post.id,
            state: 'editing',
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(
          Group::AUTO_GROUPS[:staff],
          group.id
        )

        expect(message.user_ids).to contain_exactly(
          *private_message.allowed_users.pluck(:id)
        )
      end

      it 'publishes the right message when closing composer in public topic' do
        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: public_topic.id,
            state: described_class::CLOSED_STATE,
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to eq(nil)
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the right message when closing composer in private topic' do
        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: private_topic.id,
            state: described_class::CLOSED_STATE,
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(group.id)
        expect(message.user_ids).to eq(nil)
      end

      it 'publishes the right message when closing composer in private message' do
        post = Fabricate(:post, topic: private_message, user: user)

        messages = MessageBus.track_publish do
          post '/presence/publish.json', params: {
            topic_id: private_message.id,
            state: described_class::CLOSED_STATE,
          }

          expect(response.status).to eq(200)
        end

        expect(messages.length).to eq(1)

        message = messages.first

        expect(message.group_ids).to contain_exactly(
          Group::AUTO_GROUPS[:staff],
          group.id
        )

        expect(message.user_ids).to contain_exactly(
          *private_message.allowed_users.pluck(:id)
        )
      end
    end
  end
end
