# frozen_string_literal: true

RSpec.describe PostReadersController do
  describe "#index" do
    fab!(:admin)
    fab!(:reader, :user)

    before { sign_in(admin) }

    before do
      @group = Fabricate(:group)
      @group_message = Fabricate(:private_message_topic, allowed_groups: [@group])
      @post = Fabricate(:post, topic: @group_message, post_number: 3)
    end

    context "when the user has access to readers data" do
      before do
        @group.update!(publish_read_state: true)
        @group.add(admin)
        @group.add(reader)
      end

      it "returns an empty list when nobody has read the topic" do
        get "/post_readers.json", params: { id: @post.id }

        readers = response.parsed_body["post_readers"]

        expect(readers).to be_empty
      end

      it "returns an user who read until that post" do
        TopicUser.create!(user: reader, topic: @group_message, last_read_post_number: 3)

        get "/post_readers.json", params: { id: @post.id }
        reader_data = response.parsed_body["post_readers"].first

        assert_reader_is_correctly_serialized(reader_data, reader, @post)
      end

      it "returns an user who read pass that post" do
        TopicUser.create!(user: reader, topic: @group_message, last_read_post_number: 4)

        get "/post_readers.json", params: { id: @post.id }
        reader_data = response.parsed_body["post_readers"].first

        assert_reader_is_correctly_serialized(reader_data, reader, @post)
      end

      it "return an empty list when nodobody read until that post" do
        TopicUser.create!(user: reader, topic: @group_message, last_read_post_number: 1)

        get "/post_readers.json", params: { id: @post.id }
        readers = response.parsed_body["post_readers"]

        expect(readers).to be_empty
      end

      it "doesn't include users without reading progress on first post" do
        @post.update(post_number: 1)
        TopicUser.create!(user: reader, topic: @group_message, last_read_post_number: nil)

        get "/post_readers.json", params: { id: @post.id }
        readers = response.parsed_body["post_readers"]

        expect(readers).to be_empty
      end

      it "doesn't include staged users" do
        TopicUser.create!(user: reader, topic: @group_message, last_read_post_number: 4)
        reader.update(staged: true)

        get "/post_readers.json", params: { id: @post.id }
        readers = response.parsed_body["post_readers"]

        expect(readers).to be_empty
      end

      it "doesn't include non-staff users when the post is a whisper" do
        @post.update(post_type: Post.types[:whisper])
        non_staff_user = Fabricate(:user)
        TopicUser.create!(user: non_staff_user, topic: @group_message, last_read_post_number: 4)

        get "/post_readers.json", params: { id: @post.id }
        readers = response.parsed_body["post_readers"]

        expect(readers).to be_empty
      end

      it "includes staff users when the post is a whisper" do
        @post.update(post_type: Post.types[:whisper])
        admin = Fabricate(:admin)
        TopicUser.create!(user: admin, topic: @group_message, last_read_post_number: 4)

        get "/post_readers.json", params: { id: @post.id }
        reader_data = response.parsed_body["post_readers"].first

        assert_reader_is_correctly_serialized(reader_data, admin, @post)
      end

      it "doesn't include bots" do
        TopicUser.create!(
          user: Discourse.system_user,
          topic: @group_message,
          last_read_post_number: 4,
        )

        get "/post_readers.json", params: { id: @post.id }
        readers = response.parsed_body["post_readers"]

        expect(readers).to be_empty
      end
    end

    def assert_reader_is_correctly_serialized(reader_data, reader, post)
      expect(reader_data["avatar_template"]).to eq reader.avatar_template
      expect(reader_data["username"]).to eq reader.username
      expect(reader_data["username_lower"]).to eq reader.username_lower
    end

    it "returns forbidden if no group has publish_read_state enabled" do
      get "/post_readers.json", params: { id: @post.id }

      expect(response).to be_forbidden
    end

    it "returns forbidden if current_user is not a member of a group with publish_read_state enabled" do
      @group.update!(publish_read_state: true)

      get "/post_readers.json", params: { id: @post.id }

      expect(response).to be_forbidden
    end
  end
end
