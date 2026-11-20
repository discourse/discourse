# frozen_string_literal: true

RSpec.describe PostReadersController do
  describe "#staff_report" do
    fab!(:post)
    fab!(:moderator)
    fab!(:reader, :user)
    fab!(:other_reader, :user)

    def report_for(post)
      get "/post_readers/#{post.id}/staff_report.json",
          headers: {
            "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
          }
    end

    it "requires the site to opt in" do
      sign_in(moderator)
      report_for(post)
      expect(response.status).to eq(404)
    end

    context "when enabled" do
      before { SiteSetting.enable_post_readers_modal = true }

      it "denies regular users" do
        sign_in(reader)
        report_for(post)
        expect(response).to be_forbidden
      end

      it "denies access to a post the moderator cannot see" do
        category = Fabricate(:private_category, group: Fabricate(:group))
        restricted = Fabricate(:post, topic: Fabricate(:topic, category:))
        sign_in(moderator)
        report_for(restricted)
        expect(response).to be_forbidden
      end

      it "does not report readers of a personal message" do
        message = Fabricate(:private_message_post, user: moderator, recipient: reader)
        sign_in(moderator)
        report_for(message)
        expect(response.status).to eq(404)
      end

      it "does not report readers of a deleted topic" do
        deleted_post = Fabricate(:post)
        deleted_post.topic.trash!
        sign_in(Fabricate(:admin))

        report_for(deleted_post)

        expect(response).to have_http_status(:not_found)
      end

      it "does not report readers of a whisper" do
        whisper = Fabricate(:post, topic: post.topic, post_type: Post.types[:whisper])
        sign_in(Fabricate(:admin))
        report_for(whisper)
        expect(response.status).to eq(404)
      end

      it "returns timing-backed readers and their last topic visits" do
        visit = 1.hour.ago.change(usec: 0)
        TopicUser.create!(topic: post.topic, user: reader, last_visited_at: visit)
        TopicUser.create!(
          topic: post.topic,
          user: post.user,
          last_read_post_number: post.post_number,
        )
        PostTiming.create!(
          topic: post.topic,
          post_number: post.post_number,
          user: reader,
          msecs: 700,
        )
        PostTiming.create!(
          topic: post.topic,
          post_number: post.post_number,
          user: other_reader,
          msecs: 600,
        )
        PostTiming.create!(
          topic: post.topic,
          post_number: post.post_number,
          user: post.user,
          msecs: 1,
        )
        sign_in(moderator)

        report_for(post)

        expect(response.status).to eq(200)
        expect(response.parsed_body["readers"].pluck("username", "last_visited_at")).to eq(
          [[reader.username, visit.as_json], [other_reader.username, nil]],
        )
      end
    end
  end

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

    it "returns forbidden if current_user cannot see members of the read state group" do
      member = Fabricate(:user)
      hidden_member = Fabricate(:user)

      @group.update!(
        visibility_level: Group.visibility_levels[:members],
        members_visibility_level: Group.visibility_levels[:staff],
        publish_read_state: true,
      )
      @group.add(member)
      @group.add(hidden_member)
      TopicUser.create!(
        user: hidden_member,
        topic: @group_message,
        last_read_post_number: @post.post_number,
      )

      sign_in(member)
      get "/post_readers.json", params: { id: @post.id }

      expect(response).to be_forbidden
      expect(response.parsed_body["error_type"]).to eq("invalid_access")
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

    it "returns forbidden when a non-staff group member requests readers for a whisper post" do
      regular_user = Fabricate(:user)
      @group.update!(publish_read_state: true)
      @group.add(regular_user)
      sign_in(regular_user)

      @post.update!(post_type: Post.types[:whisper])
      staff_reader = Fabricate(:admin)
      @group.add(staff_reader)
      TopicUser.create!(user: staff_reader, topic: @group_message, last_read_post_number: 4)

      get "/post_readers.json", params: { id: @post.id }

      expect(response).to be_forbidden
    end
  end
end
