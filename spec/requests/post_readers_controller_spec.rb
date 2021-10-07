# frozen_string_literal: true

require 'rails_helper'

describe PostReadersController do
  describe '#index' do
    fab!(:admin) { Fabricate(:admin) }
    fab!(:reader) { Fabricate(:user) }
    fab!(:group) { Fabricate(:group) }

    fab!(:category) do
      Fabricate(:category, publish_read_state: true)
    end

    fab!(:topic) { Fabricate(:topic, category: category) }
    fab!(:post) { Fabricate(:post, topic: topic) }

    fab!(:group_message) do
      Fabricate(:private_message_topic, allowed_groups: [group])
    end

    fab!(:group_message_post) do
      Fabricate(:post, topic: group_message, post_number: 3)
    end

    before { sign_in(admin) }

    context 'When the user has access to readers data' do
      before do
        group.update!(publish_read_state: true)
        group.add(admin)
        group.add(reader)
      end

      it 'returns an empty list when nobody has read the topic' do
        get '/post_readers.json', params: { id: group_message_post.id }

        readers = response.parsed_body['post_readers']

        expect(readers).to be_empty
      end

      it 'returns an user who read until that post' do
        TopicUser.create!(user: reader, topic: group_message, last_read_post_number: 3)

        get '/post_readers.json', params: { id: group_message_post.id }
        reader_data = response.parsed_body['post_readers'].first

        assert_reader_is_correctly_serialized(reader_data, reader, group_message_post)
      end

      it 'returns an user who read pass that post' do
        TopicUser.create!(user: reader, topic: group_message, last_read_post_number: 4)

        get '/post_readers.json', params: { id: group_message_post.id }
        reader_data = response.parsed_body['post_readers'].first

        assert_reader_is_correctly_serialized(reader_data, reader, group_message_post)
      end

      it 'return an empty list when nodobody read until that post' do
        TopicUser.create!(user: reader, topic: group_message, last_read_post_number: 1)

        get '/post_readers.json', params: { id: group_message_post.id }
        readers = response.parsed_body['post_readers']

        expect(readers).to be_empty
      end

      it "doesn't include users without reading progress on first post" do
        group_message_post.update!(post_number: 1)
        TopicUser.create!(user: reader, topic: group_message, last_read_post_number: nil)

        get '/post_readers.json', params: { id: group_message_post.id }
        readers = response.parsed_body['post_readers']

        expect(readers).to be_empty
      end

      it "doesn't include staged users" do
        TopicUser.create!(user: reader, topic: group_message, last_read_post_number: 4)
        reader.update(staged: true)

        get '/post_readers.json', params: { id: group_message_post.id }
        readers = response.parsed_body['post_readers']

        expect(readers).to be_empty
      end

      it "doesn't include non-staff users when the post is a whisper" do
        group_message_post.update!(post_type: Post.types[:whisper])
        non_staff_user = Fabricate(:user)
        TopicUser.create!(user: non_staff_user, topic: group_message, last_read_post_number: 4)

        get '/post_readers.json', params: { id: group_message_post.id }
        readers = response.parsed_body['post_readers']

        expect(readers).to be_empty
      end

      it "includes staff users when the post is a whisper" do
        group_message_post.update!(post_type: Post.types[:whisper])
        admin = Fabricate(:admin)
        TopicUser.create!(user: admin, topic: group_message, last_read_post_number: 4)

        get '/post_readers.json', params: { id: group_message_post.id }
        reader_data = response.parsed_body['post_readers'].first

        assert_reader_is_correctly_serialized(reader_data, admin, group_message_post)
      end

      it "doesn't include bots" do
        TopicUser.create!(user: Discourse.system_user, topic: group_message, last_read_post_number: 4)

        get '/post_readers.json', params: { id: group_message_post.id }
        readers = response.parsed_body['post_readers']

        expect(readers).to be_empty
      end

      it 'returns the right response for a valid topic' do
        SiteSetting.allow_publish_read_state_on_categories = true

        TopicUser.create!(
          user: admin,
          topic: topic,
          last_read_post_number: post.post_number,
          first_visited_at: Time.zone.now
        )

        get '/post_readers.json', params: { id: post.id }

        expect(response.status).to eq(200)

        readers = response.parsed_body['post_readers']

        expect(readers.length).to eq(1)
        expect(readers[0]["first_visited_at"].present?).to eq(true)
      end

      it 'does not include first_visited_at attribute for non topic post' do
        SiteSetting.allow_publish_read_state_on_categories = true

        post_2 = Fabricate(:post, topic: topic)

        TopicUser.create!(
          user: admin,
          topic: topic,
          last_read_post_number: post_2.post_number,
          first_visited_at: Time.zone.now
        )

        get '/post_readers.json', params: { id: post_2.id }

        expect(response.status).to eq(200)

        readers = response.parsed_body['post_readers']

        expect(readers.length).to eq(1)
        expect(readers[0]["first_visited_at"].blank?).to eq(true)
      end
    end

    def assert_reader_is_correctly_serialized(reader_data, reader, post)
      expect(reader_data['id']).to eq(reader.id)
      expect(reader_data['avatar_template']).to eq reader.avatar_template
      expect(reader_data['username']).to eq reader.username
      expect(reader_data['username_lower']).to eq reader.username_lower
      expect(reader_data['first_visited_at'].blank?).to eq(true)
    end

    it 'returns forbidden if no group has publish_read_state enabled' do
      get '/post_readers.json', params: { id: group_message_post.id }

      expect(response).to be_forbidden
    end

    it 'returns forbidden if current_user is not a member of a group with publish_read_state enabled' do
      group.update!(publish_read_state: true)

      get '/post_readers.json', params: { id: group_message_post.id }

      expect(response).to be_forbidden
    end

    it 'returns forbidden if publish read state site setting for category is not enabled' do
      SiteSetting.allow_publish_read_state_on_categories = false

      get '/post_readers.json', params: { id: post.id }

      expect(response).to be_forbidden
    end

    it 'returns forbidden if publishing read state of posts in a category is disabled' do
      category.update!(publish_read_state: false)
      SiteSetting.allow_publish_read_state_on_categories = true

      get '/post_readers.json', params: { id: post.id }

      expect(response).to be_forbidden
    end
  end
end
