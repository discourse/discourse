# coding: utf-8
# frozen_string_literal: true

RSpec.describe TopicsController do
  fab!(:topic)
  fab!(:dest_topic, :topic)
  fab!(:invisible_topic) { Fabricate(:topic, visible: false) }

  fab!(:pm, :private_message_topic)

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post_author1) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post_author2, :user)
  fab!(:post_author3, :user)
  fab!(:post_author4, :user)
  fab!(:post_author5, :user)
  fab!(:post_author6, :user)
  fab!(:moderator)
  fab!(:admin)
  fab!(:trust_level_0)
  fab!(:trust_level_1)
  fab!(:trust_level_4)

  fab!(:category)
  fab!(:tracked_category, :category)
  fab!(:shared_drafts_category, :category)
  fab!(:staff_category) do
    Fabricate(:category).tap do |staff_category|
      staff_category.set_permissions(staff: :full)
      staff_category.save!
    end
  end

  fab!(:group_user) { Fabricate(:group_user, user:) }
  fab!(:tag)

  before { SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:everyone] }

  describe "topic_header plugin outlet" do
    fab!(:another_topic) { Fabricate(:topic, title: "Another topic by me", user: post_author1) }

    before { global_setting(:load_plugins?, true) }

    it "renders the connector templates from multiple plugins" do
      get "/t/#{topic.slug}/#{topic.id}"

      expect(response.status).to eq(200)
      expect(response.body).to include("Fixture from my_plugin template 1: #{topic.title}")
      expect(response.body).to include("Fixture from my_plugin template 2: #{topic.title}")
      expect(response.body).to include("Fixture from my_plugin_2 template 1: #{topic.title}")
      expect(response.body).to include("Fixture from my_plugin_2 template 2: #{topic.title}")
      expect(response.body).not_to include("Fixture from my_plugin_3 template 1: #{topic.title}")

      get "/t/#{another_topic.slug}/#{another_topic.id}"

      expect(response.status).to eq(200)
      expect(response.body).to include("Fixture from my_plugin template 1: #{another_topic.title}")
      expect(response.body).to include("Fixture from my_plugin template 2: #{another_topic.title}")

      expect(response.body).to include(
        "Fixture from my_plugin_2 template 1: #{another_topic.title}",
      )

      expect(response.body).to include(
        "Fixture from my_plugin_2 template 2: #{another_topic.title}",
      )

      expect(response.body).not_to include(
        "Fixture from my_plugin_3 template 1: #{another_topic.title}",
      )
    end
  end

  describe "#wordpress" do
    before { sign_in(moderator) }

    fab!(:p1) { Fabricate(:post, user: moderator) }
    fab!(:p2) { Fabricate(:post, topic: p1.topic, user: moderator) }

    it "returns the JSON in the format our wordpress plugin needs" do
      SiteSetting.external_system_avatars_url = ""

      get "/t/#{p1.topic.id}/wordpress.json", params: { best: 3 }

      expect(response.status).to eq(200)
      json = response.parsed_body

      # The JSON has the data the wordpress plugin needs
      expect(json["id"]).to eq(p1.topic.id)
      expect(json["posts_count"]).to eq(2)
      expect(json["filtered_posts_count"]).to eq(2)

      # Posts
      expect(json["posts"].size).to eq(1)
      post = json["posts"][0]
      expect(post["id"]).to eq(p2.id)
      expect(post["username"]).to eq(moderator.username)
      expect(post["avatar_template"]).to eq(
        "#{Discourse.base_url_no_prefix}#{moderator.avatar_template}",
      )
      expect(post["name"]).to eq(moderator.name)
      expect(post["created_at"]).to be_present
      expect(post["cooked"]).to eq(p2.cooked)

      # Participants
      expect(json["participants"].size).to eq(1)
      participant = json["participants"][0]
      expect(participant["id"]).to eq(moderator.id)
      expect(participant["username"]).to eq(moderator.username)
      expect(participant["avatar_template"]).to eq(
        "#{Discourse.base_url_no_prefix}#{moderator.avatar_template}",
      )
    end

    it "does not error out when using invalid parameters" do
      get "/t/#{p1.topic.id}/wordpress.json", params: { topic_id: 1, best: { leet: "haxx0r" } }

      expect(response.status).to eq(400)
    end
  end

  describe "#move_posts" do
    before do
      SiteSetting.min_topic_title_length = 2
      SiteSetting.tagging_enabled = true
    end

    it "needs you to be logged in" do
      post "/t/111/move-posts.json", params: { title: "blah", post_ids: [1, 2, 3] }
      expect(response.status).to eq(403)
    end

    describe "moving to a new topic" do
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1) }
      let(:p2) { Fabricate(:post, user: user, post_number: 2, topic: p1.topic) }
      let(:topic) { p1.topic }

      it "raises an error without post_ids" do
        sign_in(moderator)
        post "/t/#{topic.id}/move-posts.json", params: { title: "blah" }
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        sign_in(user)

        post "/t/#{topic.id}/move-posts.json", params: { title: "blah", post_ids: [p1.id, p2.id] }

        expect(response).to be_forbidden
      end

      it "raises an error when the OP is not a regular post" do
        sign_in(moderator)
        p2 =
          Fabricate(
            :post,
            user: post_author1,
            topic: topic,
            post_number: 2,
            post_type: Post.types[:whisper],
          )
        p3 = Fabricate(:post, user: post_author2, topic: topic, post_number: 3)

        post "/t/#{topic.id}/move-posts.json", params: { title: "blah", post_ids: [p2.id, p3.id] }
        expect(response.status).to eq(422)

        result = response.parsed_body

        expect(result["errors"]).to be_present
      end

      context "with success" do
        fab!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: p1.topic) }

        before { sign_in(admin) }

        it "returns success" do
          expect do
            post "/t/#{topic.id}/move-posts.json",
                 params: {
                   title: "Logan is a good movie",
                   post_ids: [p2.id],
                   category_id: category.id,
                   tags: %w[foo bar],
                 }
          end.to change { Topic.count }.by(1).and change { Tag.count }.by(2)

          expect(response.status).to eq(200)

          result = response.parsed_body

          expect(result["success"]).to eq(true)

          new_topic = Topic.last
          expect(result["url"]).to eq(new_topic.relative_url)
          expect(new_topic.excerpt).to eq(p2.excerpt_for_topic)
          expect(Tag.all.pluck(:name)).to include("foo", "bar")
        end

        it "moves posts to new topic with existing tags" do
          tag1 = Fabricate(:tag, name: "existing-tag")
          tag2 = Fabricate(:tag, name: "another-tag")

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 title: "Topic with tags",
                 post_ids: [p2.id],
                 category_id: category.id,
                 tag_ids: [tag1.id, tag2.id],
               }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(true)

          new_topic = Topic.last
          expect(new_topic.tags).to contain_exactly(tag1, tag2)
        end

        it "duplicates post to new topic and keeps original post in place" do
          expect do
            post "/t/#{topic.id}/move-posts.json",
                 params: {
                   title: "Logan is a good movie",
                   post_ids: [p2.id],
                   freeze_original: true,
                 }
          end.to change { Topic.count }.by(1)
          expect(response.status).to eq(200)
          expect(topic.post_ids).to include(p2.id)
        end

        describe "when topic has been deleted" do
          it "still allows posts to be moved" do
            PostDestroyer.new(admin, topic.first_post, context: "Automated testing").destroy

            expect(topic.reload.deleted_at).to_not be_nil

            expect do
              post "/t/#{topic.id}/move-posts.json",
                   params: {
                     title: "Logan is a good movie",
                     post_ids: [p2.id],
                     category_id: category.id,
                   }
            end.to change { Topic.count }.by(1)

            expect(response.status).to eq(200)

            result = response.parsed_body

            expect(result["success"]).to eq(true)
            expect(result["url"]).to eq(Topic.last.relative_url)
          end
        end
      end

      it "returns JSON with a false success" do
        sign_in(moderator)
        post "/t/#{topic.id}/move-posts.json", params: { post_ids: [p2.id] }
        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(false)
        expect(result["url"]).to be_blank
      end

      it "moves the child posts too" do
        sign_in(moderator)
        p1 = Fabricate(:post, topic: topic, user: moderator)
        p2 = Fabricate(:post, topic: topic, user: moderator, reply_to_post_number: p1.post_number)
        PostReply.create(post_id: p1.id, reply_post_id: p2.id)

        post "/t/#{topic.id}/move-posts.json",
             params: {
               title: "new topic title",
               post_ids: [p1.id],
               reply_post_ids: [p1.id],
             }
        expect(response.status).to eq(200)

        p1.reload
        p2.reload

        new_topic_id = response.parsed_body["url"].split("/").last.to_i
        new_topic = Topic.find(new_topic_id)
        expect(p1.topic.id).to eq(new_topic.id)
        expect(p2.topic.id).to eq(new_topic.id)
        expect(p2.reply_to_post_number).to eq(p1.post_number)
      end
    end

    describe "moving posts as a group moderator" do
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category, user: post_author1) }
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: topic) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      context "with a new topic destination" do
        it "moves the posts" do
          expect do
            post "/t/#{topic.id}/move-posts.json",
                 params: {
                   title: "Logan is a good movie",
                   post_ids: [p2.id],
                   category_id: category.id,
                 }
          end.to change { Topic.count }.by(1)

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to eq(Topic.last.relative_url)
        end

        it "rejects private destination parameters and posts outside the moderated category" do
          post "/t/#{topic.id}/move-posts.json",
               params: {
                 title: "Logan is a good movie",
                 post_ids: [p2.id],
                 category_id: staff_category.id,
               }

          expect(response).to be_forbidden

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 title: "Logan is a good movie",
                 post_ids: [p2.id],
                 category_id: staff_category.id,
                 destination_topic_id: dest_topic.id,
               }

          expect(response).to be_forbidden
          expect(response.parsed_body["errors"]).to be_present
          expect(p2.reload.topic_id).to eq(topic.id)

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 title: "Logan is a good movie",
                 post_ids: [p2.id],
                 category_id: staff_category.id,
                 archetype: Archetype.default,
               }

          expect(response).to be_forbidden
          expect(response.parsed_body["errors"]).to be_present
          expect(p2.reload.topic_id).to eq(topic.id)

          topic.update!(category: nil)

          post "/t/#{topic.id}/move-posts.json", params: { title: "blah", post_ids: [p1.id, p2.id] }

          expect(response).to be_forbidden
        end

        it "ignores unrelated post IDs without exposing their reviewables" do
          restricted_category =
            Fabricate(:private_category, group: Fabricate(:group), user: post_author1)
          restricted_topic = Fabricate(:topic, category: restricted_category, user: post_author1)
          restricted_post = Fabricate(:post, topic: restricted_topic, user: post_author1)
          restricted_reviewable =
            Fabricate(
              :reviewable_flagged_post,
              target: restricted_post,
              target_created_by: restricted_post.user,
              topic: restricted_topic,
              category: restricted_category,
            )

          expect(Reviewable.list_for(user, preload: false)).not_to include(restricted_reviewable)

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 title: "Logan is a good movie",
                 post_ids: [p2.id, restricted_post.id],
                 category_id: category.id,
               }

          aggregate_failures do
            expect(response.status).to eq(200)
            expect(response.parsed_body["success"]).to eq(true)
            expect(restricted_reviewable.reload).to have_attributes(
              topic_id: restricted_topic.id,
              category_id: restricted_category.id,
            )
            expect(Reviewable.list_for(user, preload: false)).not_to include(restricted_reviewable)
          end
        end
      end

      context "with an existing topic destination" do
        it "moves the posts" do
          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 destination_topic_id: dest_topic.id,
               }

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq("success" => true, "url" => dest_topic.relative_url)
          expect(p2.reload.topic_id).to eq(dest_topic.id)
        end

        it "rejects private destinations and sources outside the moderated category" do
          dest_topic.update!(category: staff_category)

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 destination_topic_id: dest_topic.id,
               }

          expect(response).to be_forbidden
          expect(response.parsed_body["errors"]).to be_present
          expect(p2.reload.topic_id).to eq(topic.id)
          expect(topic.reload.deleted_at).to be_nil

          dest_topic.update!(category: nil)
          topic.update!(category: nil)

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p1.id, p2.id],
                 destination_topic_id: dest_topic.id,
               }

          expect(response).to be_forbidden
        end

        it "moves posts in chronological order" do
          p1.update!(created_at: dest_topic.created_at - 1.hour)

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p1.id],
                 destination_topic_id: dest_topic.id,
                 chronological_order: "true",
               }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to be_present
        end
      end
    end

    describe "moving posts as a TL4 user who can only read the source category" do
      fab!(:read_only_group, :group)
      fab!(:private_category) do
        Fabricate(
          :private_category,
          group: read_only_group,
          user: post_author1,
          permission_type: CategoryGroup.permission_types[:readonly],
        )
      end
      fab!(:private_topic) { Fabricate(:topic, category: private_category, user: post_author1) }
      fab!(:private_post) { Fabricate(:post, topic: private_topic, user: post_author2) }

      before do
        GroupUser.create!(group: read_only_group, user: trust_level_4)
        sign_in(trust_level_4)
      end

      it "does not allow posts to be moved into new or existing public topics" do
        post "/t/#{private_topic.id}/move-posts.json",
             params: {
               title: "Leaked private topic content",
               post_ids: [private_post.id],
               category_id: category.id,
             }

        expect(response).to be_forbidden
        expect(private_post.reload.topic_id).to eq(private_topic.id)

        post "/t/#{private_topic.id}/move-posts.json",
             params: {
               post_ids: [private_post.id],
               destination_topic_id: dest_topic.id,
             }

        expect(response).to be_forbidden
        expect(private_post.reload.topic_id).to eq(private_topic.id)
      end
    end

    describe "moving to an existing topic" do
      before { sign_in(moderator) }

      fab!(:p1) { Fabricate(:post, user: moderator) }
      fab!(:topic) { p1.topic }
      fab!(:p2) { Fabricate(:post, user: moderator, topic: topic) }

      context "with success" do
        it "moves the post and emits the merge event" do
          events =
            DiscourseEvent.track_events do
              post "/t/#{topic.id}/move-posts.json",
                   params: {
                     post_ids: [p2.id],
                     destination_topic_id: dest_topic.id,
                   }
            end

          expect(response.status).to eq(200)
          expect(response.parsed_body).to eq("success" => true, "url" => dest_topic.relative_url)
          expect(p2.reload.topic_id).to eq(dest_topic.id)
          event = events.find { |event| event[:event_name] == :topic_merged }
          expect(event).to be_present
          expect(event[:params]).to eq([topic, dest_topic])
        end

        describe "moving a post to a restricted topic" do
          fab!(:post_author) { Fabricate(:user, last_seen_at: 1.minute.ago) }
          fab!(:source_topic) { Fabricate(:topic, user: post_author) }
          fab!(:source_post) { Fabricate(:post, topic: source_topic, user: post_author) }
          fab!(:restricted_destination_category) do
            Fabricate(:private_category, group: Group[:staff], user: post_author1)
          end
          fab!(:restricted_destination_topic) do
            Fabricate(
              :topic,
              category: restricted_destination_category,
              title: "Restricted destination",
              user: admin,
            )
          end

          it "does not publish the restricted destination title to the post author" do
            expect(post_author.guardian.can_see?(restricted_destination_topic)).to eq(false)

            messages =
              MessageBus.track_publish("/notification/#{post_author.id}") do
                Jobs.with_immediate_jobs do
                  post "/t/#{source_topic.id}/move-posts.json",
                       params: {
                         post_ids: [source_post.id],
                         destination_topic_id: restricted_destination_topic.id,
                       }
                end
              end

            expect(response.status).to eq(200)
            expect(response.parsed_body["success"]).to eq(true)
            expect(messages.map { |message| message.data.to_json }.join).not_to include(
              restricted_destination_topic.title,
            )
          end
        end

        describe "moving a post to a topic in a read-restricted category" do
          fab!(:reader) { Fabricate(:user, refresh_auto_groups: true) }
          fab!(:source_topic) { Fabricate(:topic, user: post_author1) }
          fab!(:source_op) { Fabricate(:post, topic: source_topic, user: post_author1) }
          fab!(:source_reply) { Fabricate(:post, topic: source_topic, user: post_author1) }
          fab!(:restricted_category) do
            Fabricate(:private_category, group: Group[:staff], user: post_author1)
          end
          fab!(:restricted_destination_topic) do
            Fabricate(
              :topic,
              category: restricted_category,
              title: "Top secret destination title",
              user: admin,
            )
          end

          it "does not disclose the restricted destination title in the source topic move notice" do
            expect(reader.guardian.can_see?(source_topic)).to eq(true)
            expect(reader.guardian.can_see?(restricted_destination_topic)).to eq(false)

            post "/t/#{source_topic.id}/move-posts.json",
                 params: {
                   post_ids: [source_reply.id],
                   destination_topic_id: restricted_destination_topic.id,
                 }

            expect(response.status).to eq(200)
            expect(response.parsed_body["success"]).to eq(true)

            sign_in(reader)
            get "/t/#{source_topic.id}.json"
            expect(response.status).to eq(200)

            posts = response.parsed_body["post_stream"]["posts"]
            move_notice = posts.find { |p| p["action_code"] == "split_topic" }
            expect(move_notice).to be_present
            expect(posts.map { |p| p["cooked"] }.join(" ")).not_to include(
              restricted_destination_topic.title,
            )
          end
        end

        it "duplicates post to topic and keeps original post in place" do
          expect do
            post "/t/#{topic.id}/move-posts.json",
                 params: {
                   post_ids: [p2.id],
                   destination_topic_id: dest_topic.id,
                   freeze_original: true,
                 }
          end.to change { dest_topic.posts.count }.by(1)
          expect(response.status).to eq(200)
          expect(topic.post_ids).to include(p2.id)
          expect(dest_topic.posts.find_by(raw: p2.raw)).to be_present
        end
      end

      context "with failure" do
        fab!(:p2) { Fabricate(:post, user: moderator) }
        it "returns JSON with a false success" do
          post "/t/#{topic.id}/move-posts.json", params: { post_ids: [p2.id] }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(false)
          expect(result["url"]).to be_blank
        end

        it "returns plugin validation error" do
          # stub here is to simulate validation added by plugin which would be triggered when post is moved
          PostCreator.any_instance.stubs(:skip_validations?).returns(false)

          p1.update_columns(raw: "i", cooked: "")
          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p1.id],
                 destination_topic_id: dest_topic.id,
               }

          expect(response.status).to eq(422)
          result = response.parsed_body
          expect(result["errors"]).to eq(
            [
              "Body is too short (minimum is 5 characters) and Body seems unclear, is it a complete sentence?",
            ],
          )
        end
      end

      it "moves posts in chronological order" do
        p1.update!(created_at: dest_topic.created_at - 1.hour)

        post "/t/#{topic.id}/move-posts.json",
             params: {
               post_ids: [p1.id],
               destination_topic_id: dest_topic.id,
               chronological_order: "true",
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end
    end

    describe "moving to an existing topic with read-only destination permissions as TL4" do
      fab!(:readonly_category) do
        Fabricate(:category, user: post_author1).tap do |category|
          category.set_permissions(everyone: :readonly, staff: :full)
          category.save!
        end
      end
      fab!(:restricted_write_category) do
        Fabricate(:category, user: post_author1).tap do |category|
          category.set_permissions(group_user.group => :full, :everyone => :readonly)
          category.save!
        end
      end
      fab!(:source_topic) { Fabricate(:topic, user: post_author1) }
      fab!(:source_post) { Fabricate(:post, topic: source_topic, user: trust_level_4) }
      fab!(:dest_topic_in_readonly) do
        Fabricate(:topic, category: readonly_category, user: post_author1)
      end
      fab!(:dest_topic_restricted) do
        Fabricate(:topic, category: restricted_write_category, user: post_author1)
      end

      before { sign_in(trust_level_4) }

      it "rejects read-only destinations with staff or group write permissions" do
        post "/t/#{source_topic.id}/move-posts.json",
             params: {
               post_ids: [source_post.id],
               destination_topic_id: dest_topic_in_readonly.id,
             }

        expect(response).to be_forbidden
        expect(source_post.reload.topic_id).to eq(source_topic.id)

        post "/t/#{source_topic.id}/move-posts.json",
             params: {
               post_ids: [source_post.id],
               destination_topic_id: dest_topic_restricted.id,
             }

        expect(response).to be_forbidden
        expect(source_post.reload.topic_id).to eq(source_topic.id)
      end
    end

    describe "moving to a new message" do
      fab!(:message) { pm }
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1, topic: message) }
      fab!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: message) }

      it "raises an error without post_ids" do
        sign_in(moderator)
        post "/t/#{message.id}/move-posts.json",
             params: {
               title: "blah",
               archetype: "private_message",
             }
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to move the posts" do
        sign_in(trust_level_4)

        post "/t/#{message.id}/move-posts.json",
             params: {
               title: "blah",
               post_ids: [p1.id, p2.id],
               archetype: "private_message",
             }

        expect(response.status).to eq(403)
        result = response.parsed_body
        expect(result["errors"]).to be_present
      end

      context "with success" do
        before { sign_in(admin) }

        it "returns success" do
          SiteSetting.pm_tags_allowed_for_groups = "1|2|3"

          expect do
            post "/t/#{message.id}/move-posts.json",
                 params: {
                   title: "Logan is a good movie",
                   post_ids: [p2.id],
                   archetype: "private_message",
                   tags: %w[foo bar],
                 }
          end.to change { Topic.count }.by(1).and change { Tag.count }.by(2)

          expect(response.status).to eq(200)

          result = response.parsed_body

          expect(result["success"]).to eq(true)
          expect(result["url"]).to eq(Topic.last.relative_url)
          expect(Tag.all.pluck(:name)).to include("foo", "bar")
        end

        describe "when message has been deleted" do
          it "still allows posts to be moved" do
            PostDestroyer.new(admin, message.first_post).destroy

            expect(message.reload.deleted_at).to_not be_nil

            expect do
              post "/t/#{message.id}/move-posts.json",
                   params: {
                     title: "Logan is a good movie",
                     post_ids: [p2.id],
                     archetype: "private_message",
                   }
            end.to change { Topic.count }.by(1)

            expect(response.status).to eq(200)

            result = response.parsed_body

            expect(result["success"]).to eq(true)
            expect(result["url"]).to eq(Topic.last.relative_url)
          end
        end
      end

      context "with failure" do
        it "returns JSON with a false success" do
          sign_in(moderator)
          post "/t/#{message.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 archetype: "private_message",
               }
          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(false)
          expect(result["url"]).to be_blank
        end
      end
    end

    describe "moving to an existing message" do
      before { sign_in(admin) }

      fab!(:evil_trout)
      fab!(:message) { pm }
      fab!(:p2) { Fabricate(:post, user: evil_trout, post_number: 2, topic: message) }

      fab!(:dest_message) do
        Fabricate(
          :private_message_topic,
          user: trust_level_4,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: evil_trout)],
        )
      end

      context "with success" do
        it "returns success" do
          post "/t/#{message.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 destination_topic_id: dest_message.id,
                 archetype: "private_message",
               }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to be_present
        end
      end

      context "with failure" do
        it "returns JSON with a false success" do
          post "/t/#{message.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 archetype: "private_message",
               }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(false)
          expect(result["url"]).to be_blank
        end
      end

      it "moves posts in chronological order" do
        p2.update!(created_at: dest_message.created_at - 1.hour)

        post "/t/#{message.id}/move-posts.json",
             params: {
               post_ids: [p2.id],
               destination_topic_id: dest_message.id,
               archetype: "private_message",
               chronological_order: "true",
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end
    end
  end

  describe "#merge_topic" do
    it "needs you to be logged in" do
      post "/t/111/merge-topic.json", params: { destination_topic_id: 345 }
      expect(response.status).to eq(403)
    end

    describe "merging into another topic" do
      fab!(:p1) { Fabricate(:post, user: user) }
      fab!(:topic) { p1.topic }

      it "requires a destination before merging all posts" do
        sign_in(moderator)
        post "/t/#{topic.id}/merge-topic.json"
        expect(response.status).to eq(400)

        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end

      it "raises an error when the user doesn't have permission to merge" do
        sign_in(user)
        post "/t/111/merge-topic.json", params: { destination_topic_id: 345 }
        expect(response).to be_forbidden
      end

      it "moves posts in chronological order" do
        p1.update!(created_at: dest_topic.created_at - 1.hour)

        sign_in(moderator)
        post "/t/#{topic.id}/merge-topic.json",
             params: {
               destination_topic_id: dest_topic.id,
               chronological_order: "true",
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end
    end

    describe "merging into another topic as a group moderator" do
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category, user: post_author1) }
      fab!(:p1) { Fabricate(:post, user: post_author1, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: post_author2, post_number: 2, topic: topic) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq("success" => true, "url" => dest_topic.relative_url)
        expect(p2.reload.topic_id).to eq(dest_topic.id)
      end

      it "rejects private destinations and sources outside the moderated category" do
        dest_topic.update!(category: staff_category)

        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response).to be_forbidden
        expect(response.parsed_body["errors"]).to be_present
        expect(p2.reload.topic_id).to eq(topic.id)
        expect(topic.reload.deleted_at).to be_nil

        dest_topic.update!(category: nil)
        topic.update!(category: nil)

        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response).to be_forbidden
      end

      it "moves posts in chronological order" do
        p1.update!(created_at: dest_topic.created_at - 1.hour)
        p2.update!(created_at: dest_topic.created_at - 30.minutes)

        post "/t/#{topic.id}/merge-topic.json",
             params: {
               destination_topic_id: dest_topic.id,
               chronological_order: "true",
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end
    end

    describe "merging into another message" do
      fab!(:message) { Fabricate(:private_message_topic, user: user, recipient: user_2) }
      fab!(:p1) { Fabricate(:post, topic: message, user: trust_level_4) }
      fab!(:p2) do
        Fabricate(:post, topic: message, reply_to_post_number: p1.post_number, user: user)
      end

      fab!(:dest_message) do
        Fabricate(
          :private_message_topic,
          user: trust_level_4,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: moderator)],
        )
      end

      it "requires a destination before merging all message posts" do
        sign_in(moderator)
        post "/t/#{message.id}/merge-topic.json", params: { archetype: "private_message" }
        expect(response.status).to eq(400)

        post "/t/#{message.id}/merge-topic.json",
             params: {
               destination_topic_id: dest_message.id,
               archetype: "private_message",
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end

      it "raises an error when the user doesn't have permission to merge" do
        sign_in(trust_level_4)
        post "/t/#{message.id}/merge-topic.json",
             params: {
               destination_topic_id: 345,
               archetype: "private_message",
             }
        expect(response).to be_forbidden
      end

      it "moves posts in chronological order" do
        p1.update!(created_at: dest_message.created_at - 1.hour)
        p2.update!(created_at: dest_message.created_at - 30.minutes)

        sign_in(moderator)
        post "/t/#{message.id}/merge-topic.json",
             params: {
               destination_topic_id: dest_message.id,
               archetype: "private_message",
               chronological_order: "true",
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end
    end

    describe "error handling" do
      fab!(:p1) { Fabricate(:post, user: user) }
      fab!(:topic) { p1.topic }

      it "returns a JSON error when move_posts raises RecordInvalid" do
        sign_in(moderator)

        Topic
          .any_instance
          .stubs(:move_posts)
          .raises(
            ActiveRecord::RecordInvalid.new(
              Post.new.tap { |p| p.errors.add(:base, "Something went wrong") },
            ),
          )

        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to be_present
      end
    end
  end

  describe "#change_post_owners" do
    it "needs you to be logged in" do
      post "/t/111/change-owner.json", params: { username: "user_a", post_ids: [1, 2, 3] }
      expect(response).to be_forbidden
    end

    describe "forbidden to trust_level_4s" do
      before { sign_in(trust_level_4) }

      it "correctly denies" do
        post "/t/111/change-owner.json",
             params: {
               topic_id: 111,
               username: "user_a",
               post_ids: [1, 2, 3],
             }
        expect(response).to be_forbidden
      end
    end

    describe "changing ownership" do
      fab!(:user_a, :user)
      fab!(:p1) { Fabricate(:post, user: post_author1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: post_author2, topic: topic) }

      describe "moderator signed in" do
        let!(:editor) { sign_in(moderator) }

        it "requires moderators_change_post_ownership for moderators" do
          SiteSetting.moderators_change_post_ownership = false

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          expect(response.status).to eq(403)

          SiteSetting.moderators_change_post_ownership = true

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          expect(response.status).to eq(200)
          expect(p1.reload.user).to eq(user_a)
        end
      end

      describe "admin signed in" do
        let!(:editor) { sign_in(admin) }

        it "requires ownership parameters before changing the topic and selected posts" do
          [{ post_ids: [1, 2, 3] }, { username: "user_a" }].each do |params|
            post "/t/111/change-owner.json", params: params
            expect(response.status).to eq(400)
          end

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id, p2.id],
               }

          expect(response.status).to eq(200)
          expect(topic.reload.user).to eq(user_a)
          expect(p1.reload.user).to eq(user_a)
          expect(p2.reload.user).to eq(user_a)
        end

        it "changes only the selected post while transferring topic ownership" do
          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }

          expect(response.status).to eq(200)
          expect(topic.reload.user).to eq(user_a)
          expect(p1.reload.user).to eq(user_a)
          expect(p2.reload.user).to eq(post_author2)
        end

        it "works with deleted users" do
          deleted_user = user
          t2 = Fabricate(:topic, user: deleted_user)
          p3 = Fabricate(:post, topic: t2, user: deleted_user)

          UserDestroyer.new(editor).destroy(
            deleted_user,
            delete_posts: true,
            context: "test",
            delete_as_spammer: true,
          )

          post "/t/#{t2.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p3.id],
               }

          expect(response.status).to eq(200)
          t2.reload
          p3.reload
          expect(t2.deleted_at).to be_nil
          expect(p3.user).to eq(user_a)
        end

        it "removes likes by new owner" do
          now = Time.zone.now
          freeze_time(now - 1.day)
          PostActionCreator.like(user_a, p1)
          p1.reload
          freeze_time(now)
          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          topic.reload
          p1.reload
          expect(response.status).to eq(200)
          expect(topic.user.username).to eq(user_a.username)
          expect(p1.user.username).to eq(user_a.username)
          expect(p1.like_count).to eq(0)
        end
      end

      describe "user in group signed in" do
        before { sign_in(user) }

        it "requires the user group to be allow listed" do
          SiteSetting.change_post_ownership_allowed_groups = ""

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          expect(response.status).to eq(403)

          SiteSetting.change_post_ownership_allowed_groups = "#{group_user.group_id}"

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          expect(response.status).to eq(200)
          expect(p1.reload.user).to eq(user_a)
        end
      end

      context "with API key" do
        fab!(:api_key_token) { Fabricate(:api_key, user: admin, created_by: admin).key }
        let(:api_key) { ApiKey.with_key(api_key_token).first! }

        it "requires change_owner scope to change ownership" do
          scope = ApiKeyScope.create!(resource: "topics", action: "read", api_key_id: api_key.id)

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               },
               headers: {
                 "HTTP_API_KEY" => api_key_token,
                 "HTTP_API_USERNAME" => api_key.user.username,
               }

          expect(response.status).to eq(403)
          expect(p1.reload.user).to eq(post_author1)

          scope.update!(action: "change_owner")
          api_key.reload

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               },
               headers: {
                 "HTTP_API_KEY" => api_key_token,
                 "HTTP_API_USERNAME" => api_key.user.username,
               }

          expect(response.status).to eq(200)
          expect(p1.reload.user).to eq(user_a)
        end
      end

      describe "private messages" do
        fab!(:private_category) do
          Fabricate(
            :private_category,
            group: Fabricate(:group),
            user: post_author1,
            permission_type: CategoryGroup.permission_types[:full],
          )
        end
        fab!(:private_topic) { Fabricate(:topic, category: private_category, user: post_author1) }
        fab!(:private_post) { Fabricate(:post, topic: private_topic, user: post_author1) }

        fab!(:pm_user, :user)
        fab!(:pm_topic) { Fabricate(:private_message_topic, user: pm_user, recipient: user_2) }
        fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: pm_user) }

        describe "moderator signed in" do
          before do
            SiteSetting.moderators_change_post_ownership = true
            sign_in(moderator)
          end

          it "protects private categories and messages from non-participating moderators" do
            post "/t/#{private_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [private_post.id],
                 }
            expect(response.status).to eq(403)

            post "/t/#{pm_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [pm_post.id],
                 }
            expect(response.status).to eq(403)
          end
        end

        describe "admin signed in" do
          before { sign_in(admin) }

          it "allows admins to change ownership in private messages and categories" do
            post "/t/#{pm_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [pm_post.id],
                 }
            expect(response.status).to eq(200)
            expect(pm_post.reload.user).to eq(user_a)

            post "/t/#{private_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [private_post.id],
                 }
            expect(response.status).to eq(200)
            expect(private_post.reload.user).to eq(user_a)
          end
        end

        describe "user in allowed group signed in" do
          fab!(:visible_pm_topic) do
            Fabricate(:private_message_topic, user: user, recipient: user_2)
          end
          fab!(:visible_pm_post) { Fabricate(:post, topic: visible_pm_topic, user: user) }

          before do
            SiteSetting.change_post_ownership_allowed_groups = "#{group_user.group_id}"
            sign_in(user)
          end

          it "returns 200 for visible PM" do
            post "/t/#{visible_pm_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username_lower,
                   post_ids: [visible_pm_post.id],
                 }
            expect(response.status).to eq(200)
          end

          it "requires visibility even for a user in an allowed group" do
            post "/t/#{pm_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [pm_post.id],
                 }
            expect(response.status).to eq(403)

            post "/t/#{private_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [private_post.id],
                 }
            expect(response.status).to eq(403)
          end
        end
      end
    end
  end

  describe "#change_timestamps" do
    let!(:params) { { timestamp: Time.zone.now } }

    it "needs you to be logged in" do
      put "/t/1/change-timestamp.json", params: params
      expect(response.status).to eq(403)
    end

    describe "forbidden to trust_level_4" do
      before { sign_in(trust_level_4) }

      it "correctly denies" do
        put "/t/1/change-timestamp.json", params: params
        expect(response).to be_forbidden
      end
    end

    describe "changing timestamps" do
      before do
        freeze_time
        sign_in(moderator)
      end

      let!(:old_timestamp) { Time.zone.now }
      let!(:new_timestamp) { old_timestamp - 1.day }
      let!(:topic) { Fabricate(:topic, created_at: old_timestamp, user: post_author1) }
      let!(:p1) { Fabricate(:post, user: post_author1, topic: topic, created_at: old_timestamp) }
      let!(:p2) do
        Fabricate(:post, user: post_author2, topic: topic, created_at: old_timestamp + 1.day)
      end

      it "updates post timestamps and records the change in the staff log" do
        put "/t/1/change-timestamp.json"
        expect(response.status).to eq(400)

        put "/t/#{topic.id}/change-timestamp.json", params: { timestamp: new_timestamp.to_f }

        expect(response.status).to eq(200)
        expect(topic.reload.created_at).to eq_time(new_timestamp)
        expect(p1.reload.created_at).to eq_time(new_timestamp)
        expect(p2.reload.created_at).to eq_time(old_timestamp)

        log = UserHistory.last
        expect(log.acting_user_id).to eq(moderator.id)
        expect(log.topic_id).to eq(topic.id)
        expect(log.new_value).to eq(new_timestamp.utc.to_s)
        expect(log.previous_value).to eq(old_timestamp.utc.to_s)
      end
    end
  end

  describe "#clear_pin" do
    it "needs you to be logged in" do
      put "/t/1/clear-pin.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      before { sign_in(user) }

      it "fails when the user can't see the topic" do
        put "/t/#{pm.id}/clear-pin.json"
        expect(response).to be_forbidden
      end

      it "clears the topic pin" do
        expect do put "/t/#{topic.id}/clear-pin.json" end.to change {
          TopicUser.where(topic_id: topic.id, user_id: user.id).count
        }.by(1)
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#status" do
    it "needs you to be logged in" do
      put "/t/1/status.json", params: { status: "visible", enabled: true }
      expect(response.status).to eq(403)
    end

    it "raises an exception if you can't change it" do
      sign_in(user)
      put "/t/#{topic.id}/status.json", params: { status: "visible", enabled: "true" }
      expect(response).to be_forbidden
    end

    describe "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "requires both parameters and rejects statuses outside the allowlist" do
        put "/t/#{topic.id}/status.json", params: { enabled: true }
        expect(response.status).to eq(400)

        put "/t/#{topic.id}/status.json", params: { status: "visible" }
        expect(response.status).to eq(400)

        put "/t/#{topic.id}/status.json", params: { status: "title", enabled: "true" }
        expect(response.status).to eq(400)
      end

      it "updates the topic status" do
        closed_user_topic = Fabricate(:topic, user: user, closed: true)
        Fabricate(:topic_timer, topic: closed_user_topic, status_type: TopicTimer.types[:open])

        put "/t/#{closed_user_topic.id}/status.json", params: { status: "closed", enabled: "false" }

        expect(response.status).to eq(200)
        expect(closed_user_topic.reload.closed).to eq(false)
        expect(closed_user_topic.topic_timers).to eq([])

        body = response.parsed_body

        expect(body["topic_status_update"]).to eq(nil)
      end

      it "updates the status when enabled is truthy" do
        closed_user_topic = Fabricate(:topic, user: user, closed: false)

        put "/t/#{closed_user_topic.id}/status.json", params: { status: "closed", enabled: "t" }

        expect(response.status).to eq(200)
        expect(closed_user_topic.reload.closed).to eq(true)

        put "/t/#{closed_user_topic.id}/status.json", params: { status: "closed", enabled: "0" }

        expect(response.status).to eq(200)
        expect(closed_user_topic.reload.closed).to eq(false)

        put "/t/#{closed_user_topic.id}/status.json", params: { status: "closed", enabled: true }

        expect(response.status).to eq(200)
        expect(closed_user_topic.reload.closed).to eq(true)
      end
    end

    describe "when logged in as a group member with reviewable status" do
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category, user: post_author1) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "allows a group moderator to toggle topic statuses" do
        put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "true" }

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(true)
        expect(topic.posts.last.action_code).to eq("closed.enabled")

        expect do
          put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "false" }
        end.to change { topic.reload.posts.count }.by(1)

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(false)
        expect(topic.posts.last.action_code).to eq("closed.disabled")

        expect do
          put "/t/#{topic.id}/status.json", params: { status: "archived", enabled: "true" }
        end.to change { topic.reload.posts.count }.by(1)

        expect(response.status).to eq(200)
        expect(topic.reload.archived).to eq(true)
        expect(topic.posts.last.action_code).to eq("archived.enabled")

        put "/t/#{topic.id}/status.json", params: { status: "archived", enabled: "false" }

        expect(response.status).to eq(200)
        expect(topic.reload.archived).to eq(false)
        expect(topic.posts.last.action_code).to eq("archived.disabled")

        put "/t/#{topic.id}/status.json",
            params: {
              status: "pinned",
              enabled: "true",
              until: 2.weeks.from_now,
            }

        expect(response.status).to eq(200)
        expect(topic.reload.pinned_at).to_not eq(nil)

        put "/t/#{topic.id}/status.json", params: { status: "pinned", enabled: "false" }

        expect(response.status).to eq(200)
        expect(topic.reload.pinned_at).to eq(nil)

        put "/t/#{topic.id}/status.json", params: { status: "visible", enabled: "false" }

        expect(response.status).to eq(200)
        expect(topic.reload.visible).to eq(false)
        expect(topic.reload.visibility_reason_id).to eq(
          Topic.visibility_reasons[:manually_unlisted],
        )
        expect(topic.posts.last.action_code).to eq("visible.disabled")

        put "/t/#{topic.id}/status.json", params: { status: "visible", enabled: "true" }

        expect(response.status).to eq(200)
        expect(topic.reload.visible).to eq(true)
        expect(topic.reload.visibility_reason_id).to eq(
          Topic.visibility_reasons[:manually_relisted],
        )
        expect(topic.posts.last.action_code).to eq("visible.enabled")
      end
    end

    describe "when logged in as TL4 user" do
      fab!(:staff_topic) { Fabricate(:topic, category: staff_category, user: user) }

      before { sign_in(trust_level_4) }

      it "requires TL4 topic visibility and rejects private messages before closing a visible topic" do
        put "/t/#{staff_topic.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.closed).to eq(false)

        put "/t/#{staff_topic.id}/status.json", params: { status: "archived", enabled: "true" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.archived).to eq(false)

        put "/t/#{staff_topic.id}/status.json", params: { status: "pinned", enabled: "true" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.pinned_at).to eq(nil)

        put "/t/#{staff_topic.id}/status.json", params: { status: "visible", enabled: "false" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.visible).to eq(true)

        put "/t/#{pm.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(403)
        expect(pm.reload.closed).to eq(false)

        put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(true)
      end
    end

    context "with API key" do
      fab!(:api_key_token) { Fabricate(:api_key, user: moderator, created_by: moderator).key }
      let(:api_key) { ApiKey.with_key(api_key_token).first! }

      context "when key scope has restricted params" do
        before do
          ApiKeyScope.create(
            resource: "topics",
            action: "update",
            api_key_id: api_key.id,
            allowed_parameters: {
              "category_id" => ["#{topic.category_id}"],
            },
          )
        end

        it "requires a permitted category parameter to update topic status" do
          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
                category_id: tracked_category.id,
              },
              headers: {
                "HTTP_API_KEY" => api_key_token,
                "HTTP_API_USERNAME" => api_key.user.username,
              }

          expect(response.status).to eq(403)
          expect(response.body).to include(I18n.t("invalid_access"))
          expect(topic.reload.closed).to eq(false)

          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
              },
              headers: {
                "HTTP_API_KEY" => api_key_token,
                "HTTP_API_USERNAME" => api_key.user.username,
              }

          expect(response.status).to eq(403)
          expect(response.body).to include(I18n.t("invalid_access"))
          expect(topic.reload.closed).to eq(false)

          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
                category_id: topic.category_id,
              },
              headers: {
                "HTTP_API_KEY" => api_key_token,
                "HTTP_API_USERNAME" => api_key.user.username,
              }

          expect(response.status).to eq(200)
          expect(topic.reload.closed).to eq(true)
        end
      end

      context "when key scope has no param restrictions" do
        before do
          ApiKeyScope.create(
            resource: "topics",
            action: "update",
            api_key_id: api_key.id,
            allowed_parameters: {
            },
          )
        end

        it "updates topic status" do
          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
              },
              headers: {
                "HTTP_API_KEY" => api_key_token,
                "HTTP_API_USERNAME" => api_key.user.username,
              }

          expect(response.status).to eq(200)
          expect(topic.reload.closed).to eq(true)
        end
      end
    end
  end

  describe "#destroy_timings" do
    it "needs you to be logged in" do
      delete "/t/1/timings.json"
      expect(response.status).to eq(403)
    end

    it "does not delete timings for a topic the user cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group), user: post_author1)
      private_topic = Fabricate(:topic, category: private_category, user: post_author1)
      private_post = Fabricate(:post, topic: private_topic, user: post_author1)
      PostTiming.create!(
        topic: private_topic,
        user: user,
        post_number: private_post.post_number,
        msecs: 1000,
      )
      TopicUser.create!(topic: private_topic, user: user)

      sign_in(user)
      delete "/t/#{private_topic.id}/timings.json"

      aggregate_failures do
        expect(response.status).to eq(404)
        expect(response.parsed_body["error_type"]).to eq("not_found")
        expect(PostTiming.where(topic: private_topic, user: user)).to exist
        expect(TopicUser.where(topic: private_topic, user: user)).to exist
      end
    end

    def topic_user_post_timings_count(user, topic)
      [TopicUser, PostTiming].map { |klass| klass.where(user: user, topic: topic).count }
    end

    it "retains topic timing while removing only the last post" do
      freeze_time

      post1 = create_post
      user = post1.user

      topic = post1.topic

      post2 = create_post(topic_id: topic.id)

      PostTiming.create!(topic: topic, user: user, post_number: 2, msecs: 100)

      user.user_stat.update!(first_unread_at: Time.now + 1.week)

      topic_user = TopicUser.find_by(topic_id: topic.id, user_id: user.id)

      topic_user.update!(last_read_post_number: 2)

      # ensure we have 2 notifications
      # fake notification on topic but it is read
      first_notification =
        Notification.create!(
          user_id: user.id,
          topic_id: topic.id,
          data: "{}",
          read: true,
          notification_type: 1,
        )

      freeze_time 1.minute.from_now
      PostAlerter.post_created(post2)

      second_notification =
        user.notifications.where(topic_id: topic.id).order(created_at: :desc).first
      second_notification.update!(read: true)

      sign_in(user)

      delete "/t/#{topic.id}/timings.json?last=1"

      expect(PostTiming.where(topic: topic, user: user, post_number: 2).exists?).to eq(false)
      expect(PostTiming.where(topic: topic, user: user, post_number: 1).exists?).to eq(true)

      expect(TopicUser.where(topic: topic, user: user, last_read_post_number: 1).exists?).to eq(
        true,
      )

      user.user_stat.reload
      expect(user.user_stat.first_unread_at).to eq_time(topic.updated_at)

      first_notification.reload
      second_notification.reload
      expect(first_notification.read).to eq(true)
      expect(second_notification.read).to eq(false)

      PostDestroyer.new(admin, post2).destroy

      delete "/t/#{topic.id}/timings.json?last=1"

      expect(PostTiming.where(topic: topic, user: user, post_number: 1).exists?).to eq(false)
      expect(TopicUser.where(topic: topic, user: user, last_read_post_number: nil).exists?).to eq(
        true,
      )
    end

    context "when logged in" do
      fab!(:user_topic) { Fabricate(:topic, user: user) }
      fab!(:user_post) { Fabricate(:post, user: user, topic: user_topic, post_number: 2) }

      before do
        sign_in(user)
        TopicUser.create!(topic: user_topic, user: user)
        PostTiming.create!(topic: user_topic, user: user, post_number: 2, msecs: 1000)
      end

      it "deletes the forum topic user and post timings records" do
        expect do delete "/t/#{user_topic.id}/timings.json" end.to change {
          topic_user_post_timings_count(user, user_topic)
        }.from([1, 1]).to([0, 0])
      end
    end

    context "for private messages" do
      fab!(:pm_post, :private_message_post)
      fab!(:pm_topic) { pm_post.topic }
      fab!(:pm_user) { pm_topic.user }

      before do
        sign_in(pm_user)
        TopicUser.create!(
          topic: pm_topic,
          user: pm_user,
          last_read_post_number: 1,
          notification_level: TopicUser.notification_levels[:watching],
        )
        PostTiming.create!(topic: pm_topic, user: pm_user, post_number: 1, msecs: 1000)
      end

      it "publishes a message to update the client-side tracking state" do
        messages =
          MessageBus.track_publish(PrivateMessageTopicTrackingState.user_channel(pm_user.id)) do
            delete "/t/#{pm_topic.id}/timings.json"
          end

        expect(messages.size).to eq(1)
        expect(messages.first.data["message_type"]).to eq("read")
        expect(messages.first.data["topic_id"]).to eq(pm_topic.id)
      end
    end
  end

  describe "#mute/unmute" do
    it "needs you to be logged in" do
      put "/t/99/mute.json"
      expect(response.status).to eq(403)
    end
  end

  describe "#recover" do
    it "does not recover a topic for an anonymous user" do
      put "/t/1/recover.json"
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      fab!(:topic) { Fabricate(:topic, user: user, deleted_at: Time.now, deleted_by: moderator) }
      fab!(:post) do
        Fabricate(
          :post,
          user: user,
          topic: topic,
          post_number: 1,
          deleted_at: Time.now,
          deleted_by: moderator,
        )
      end

      describe "without access" do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          sign_in(user)
          put "/t/#{topic.id}/recover.json"
          expect(response).to be_forbidden
        end

        it "raises an exception when only the user's own deleted reply survives" do
          Fabricate(:post, topic: topic, user: user, post_number: 2, user_deleted: true)
          sign_in(user)

          put "/t/#{topic.id}/recover.json"

          expect(response).to be_forbidden
          expect(topic.reload).to be_trashed
        end
      end

      context "with permission" do
        before { sign_in(moderator) }

        it "recovers the topic" do
          put "/t/#{topic.id}/recover.json"
          topic.reload
          post.reload
          expect(response.status).to eq(200)
          expect(topic.trashed?).to be_falsey
          expect(post.trashed?).to be_falsey
        end
      end
    end

    context "when logged in as a category group moderator" do
      fab!(:private_category) do
        Fabricate(:private_category, group: Fabricate(:group), user: post_author1)
      end
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category: private_category, group: group_user.group)
      end
      fab!(:private_topic) do
        Fabricate(
          :topic,
          user: post_author1,
          category: private_category,
          deleted_at: Time.now,
          deleted_by: moderator,
        )
      end
      fab!(:private_post) do
        Fabricate(
          :post,
          topic: private_topic,
          user: post_author1,
          post_number: 1,
          deleted_at: Time.now,
          deleted_by: moderator,
        )
      end

      before do
        SiteSetting.enable_category_group_moderation = true
        sign_in(user)
      end

      it "requires category group moderators to see a topic before recovering it" do
        put "/t/#{private_topic.id}/recover.json"

        expect(response).to be_forbidden
        expect(private_topic.reload.trashed?).to be_truthy

        private_category.set_permissions(group_user.group => :full)
        private_category.save!

        put "/t/#{private_topic.id}/recover.json"

        expect(response.status).to eq(200)
        expect(private_topic.reload.trashed?).to be_falsey
      end
    end
  end

  describe "#delete" do
    it "does not delete a topic for an anonymous user" do
      delete "/t/1.json"
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      fab!(:topic) { Fabricate(:topic, user: user, created_at: 48.hours.ago) }
      fab!(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

      describe "without access" do
        it "raises an exception when the user doesn't have permission to delete the topic" do
          sign_in(user)
          delete "/t/#{topic.id}.json"
          expect(response.status).to eq(422)
        end
      end

      describe "with permission" do
        before { sign_in(moderator) }

        it "deletes the topic" do
          delete "/t/#{topic.id}.json"
          expect(response.status).to eq(200)
          topic.reload
          expect(topic.trashed?).to be_truthy
        end
      end

      describe "with a member of delete_all_posts_and_topics_allowed_groups" do
        fab!(:group)
        fab!(:group_member, :user)

        before do
          group.add(group_member)
          SiteSetting.delete_all_posts_and_topics_allowed_groups = "1|2|#{group.id}"
          sign_in(group_member)
        end

        it "deletes the topic" do
          delete "/t/#{topic.id}.json"

          expect(response.status).to eq(200)
          expect(topic.reload.trashed?).to eq(true)
        end
      end
    end

    describe "force destroy" do
      let!(:post) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

      before do
        SiteSetting.can_permanently_delete = true

        sign_in(admin)
      end

      it "permanently deletes the topic and deleted small actions, and sanitizes the audit log" do
        small_action_post = Fabricate(:small_action, topic: topic, user: user)
        PostDestroyer.new(Discourse.system_user, post, context: "Automated testing").destroy
        PostDestroyer.new(
          Discourse.system_user,
          small_action_post,
          context: "Automated testing",
        ).destroy

        delete "/t/#{topic.id}.json", params: { force_destroy: true }

        expect(response.status).to eq(200)

        expect(Topic.find_by(id: topic.id)).to eq(nil)
        expect(Post.find_by(id: post.id)).to eq(nil)
        expect(Post.find_by(id: small_action_post.id)).to eq(nil)

        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:delete_topic_permanently],
          acting_user_id: admin.id,
        )

        expect(UserHistory.where(topic_id: topic.id, details: "(permanently deleted)").count).to eq(
          2,
        )
      end

      it "rejects permanent deletion with a live first post or a remaining reply" do
        small_action_post = Fabricate(:small_action, topic: topic, user: user)
        PostDestroyer.new(
          Discourse.system_user,
          small_action_post,
          context: "Automated testing",
        ).destroy

        delete "/t/#{topic.id}.json", params: { force_destroy: true }

        expect(response.status).to eq(403)

        other_post = Fabricate(:post, topic: topic, user: user, post_number: 3)
        PostDestroyer.new(Discourse.system_user, post, context: "Automated testing").destroy

        delete "/t/#{topic.id}.json", params: { force_destroy: true }

        expect(response.status).to eq(403)
        expect(Post.with_deleted.find(other_post.id).deleted_at).to be_nil
      end
    end

    context "when logged in as a category group moderator" do
      fab!(:private_category) do
        Fabricate(:private_category, group: Fabricate(:group), user: post_author1)
      end
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category: private_category, group: group_user.group)
      end
      fab!(:private_topic) { Fabricate(:topic, category: private_category, user: post_author1) }
      fab!(:private_post) { Fabricate(:post, topic: private_topic, user: user, post_number: 1) }

      before do
        SiteSetting.enable_category_group_moderation = true
        sign_in(user)
      end

      it "requires category group moderators to see a topic before deleting it" do
        delete "/t/#{private_topic.id}.json"

        expect(response.status).to eq(422)
        expect(private_topic.reload.trashed?).to be_falsey

        private_category.set_permissions(group_user.group => :full)
        private_category.save!

        delete "/t/#{private_topic.id}.json"

        expect(response.status).to eq(200)
        expect(private_topic.reload.trashed?).to be_truthy
      end
    end
  end

  describe "#id_for_slug" do
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    it "resolves visible slugs and rejects private or missing topics" do
      get "/t/id_for/#{topic.slug}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["topic_id"]).to eq(topic.id)
      expect(json["url"]).to eq(topic.url)
      expect(json["slug"]).to eq(topic.slug)

      get "/t/id_for/#{pm.slug}.json"
      expect(response).to be_forbidden

      get "/t/id_for/a-slug-that-does-not-exist.json"
      expect(response).to be_not_found
    end

    context "with a deleted topic" do
      it "hides deleted topics from anonymous users but resolves them for staff" do
        deleted_topic = Fabricate(:deleted_topic, user: post_author1)
        get "/t/id_for/#{deleted_topic.slug}.json"
        expect(response).to be_not_found

        sign_in(admin)

        get "/t/id_for/#{deleted_topic.slug}.json"
        expect(response).to be_successful
      end

      it "returns 403 for a deleted topic in a category the user cannot see" do
        group = Fabricate(:group)
        category = Fabricate(:category, user: post_author1)
        category.set_permissions(group => :full)
        category.save!
        deleted_topic =
          Fabricate(:topic, category: category, deleted_at: 1.day.ago, user: post_author1)

        get "/t/id_for/#{deleted_topic.slug}.json"
        expect(response).to be_forbidden
      end
    end

    it "returns the live topic when a deleted topic shares its slug" do
      deleted_topic = Fabricate(:deleted_topic, title: "Shadowed Topic A", user: post_author1)
      deleted_topic.update_column(:slug, "shadowed-slug")
      live_topic = Fabricate(:topic, title: "Shadowed Topic B", user: post_author1)
      live_topic.update_column(:slug, "shadowed-slug")

      get "/t/id_for/shadowed-slug.json"

      expect(response).to be_successful
      expect(response.parsed_body["topic_id"]).to eq(live_topic.id)
    end
  end

  describe "#update" do
    it "does not update a topic for an anonymous user" do
      put "/t/1.json", params: { slug: "xyz" }
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      fab!(:topic) { Fabricate(:topic, user: user) }

      fab!(:first_post) { Fabricate(:post, user: post_author1, topic: topic) }

      before do
        SiteSetting.editing_grace_period = 0
        sign_in(user)
      end

      it "can not change category to a disallowed category" do
        category.set_permissions(staff: :full)
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).not_to eq(category.id)
      end

      it "can not move to a category that requires topic approval" do
        category.require_topic_approval = true
        category.save!

        put "/t/#{topic.id}.json", params: { category_id: category.id }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("category.errors.move_topic_to_category_disallowed"),
        )
        expect(topic.reload.category_id).not_to eq(category.id)
      end

      it "does not let a moderator move a topic to a category they cannot see" do
        private_category =
          Fabricate(:private_category, group: Fabricate(:group), user: post_author1)
        sign_in(moderator)

        put "/t/#{topic.id}.json", params: { category_id: private_category.id }

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).not_to eq(private_category.id)
      end

      context "when updating shared drafts" do
        fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, user: post_author1) }
        fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: tracked_category) }

        it "changes destination category" do
          put "/t/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(403)
          expect(topic.shared_draft.category_id).not_to eq(category.id)
        end
      end

      it "rejects unsupported archetypes, non-digit IDs, and invalid title or category parameters" do
        put "/t/#{topic.id}.json", params: { archetype: Archetype.banner }

        topic.reload
        expect(topic.archetype).to eq(Archetype.default)

        put "/t/#{topic.id}.json", params: { archetype: "unknown" }

        expect(response.status).to eq(422)
        expect(topic.reload.archetype).to eq(Archetype.default)

        non_digit_id = "asdf"
        original_title = topic.title
        put "/t/#{non_digit_id}.json", params: { title: "This is a new title for the topic" }

        topic.reload
        expect(topic.title).to eq(original_title)
        expect(response.status).to eq(404)

        put "/t/#{topic.slug}/#{topic.id}.json", params: { title: "asdf" }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to match_array(
          [/Title is too short/, /Title seems unclear/],
        )

        put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: -1 }

        expect(response.status).to eq(422)
      end

      it "does not allow a regular user to convert a private message to a public topic" do
        private_message = Fabricate(:private_message_topic, user: user, recipient: user_2)
        Fabricate(:post, topic: private_message, user: user)
        victim_reply = Fabricate(:post, topic: private_message, user: user_2, raw: "private reply")

        sign_in(post_author2)
        get "/t/#{private_message.slug}/#{private_message.id}.json"
        blocked_status = response.status
        expect(blocked_status).to be_in([403, 404])
        expect(response.body).not_to include(victim_reply.raw)

        sign_in(user)
        put "/t/#{private_message.slug}/#{private_message.id}.json",
            params: {
              archetype: Archetype.default,
              category_id: category.id,
            }
        update_status = response.status
        update_body = response.parsed_body

        sign_in(post_author2)
        get "/t/#{private_message.slug}/#{private_message.id}.json"

        aggregate_failures do
          expect(update_status).to eq(422)
          expect(update_body["errors"]).to include(
            I18n.t("activerecord.errors.models.topic.attributes.base.unable_to_update"),
          )
          expect(private_message.reload).to be_private_message
          expect(private_message.category_id).to be_nil
          expect(response.status).to eq(blocked_status)
          expect(response.body).not_to include(victim_reply.raw)
        end
      end

      it "raises an exception when the user doesn't have permission to update the topic" do
        topic.update!(archived: true)
        put "/t/#{topic.slug}/#{topic.id}.json"

        expect(response.status).to eq(403)
      end

      context "with webhooks" do
        fab!(:post_hook, :post_web_hook)
        fab!(:topic_hook, :topic_web_hook)

        it "updates the title and emits only the topic webhook" do
          SiteSetting.tagging_enabled = true

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                title: "This is a new title for the topic",
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["basic_topic"]).to be_present
          expect(response.parsed_body).not_to have_key("tags")
          topic.reload
          expect(topic.title).to eq("This is a new title for the topic")

          # emits a topic_edited event but not a post_edited web hook event
          expect(Jobs::EmitWebHookEvent.jobs.length).to eq(1)
          job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

          expect(job_args["event_name"]).to eq("topic_edited")
          payload = JSON.parse(job_args["payload"])
          expect(payload["title"]).to eq("This is a new title for the topic")
        end

        it "emits topic and post webhooks when editing the title followed by the first post" do
          topic.update(user: user)
          topic.first_post.update(user: user)

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                title: "This is a new title for the topic",
              }

          topic.reload
          expect(topic.title).to eq("This is a new title for the topic")

          update_params = { post: { raw: "edited body", edit_reason: "typo" } }
          put "/posts/#{topic.first_post.id}.json", params: update_params

          # emits a topic_edited event and a post_edited web hook event
          expect(Jobs::EmitWebHookEvent.jobs.length).to eq(2)
          job_args = Jobs::EmitWebHookEvent.jobs[0]["args"].first

          expect(job_args["event_name"]).to eq("topic_edited")
          payload = JSON.parse(job_args["payload"])
          expect(payload["title"]).to eq("This is a new title for the topic")

          job_args = Jobs::EmitWebHookEvent.jobs[1]["args"].first

          expect(job_args["event_name"]).to eq("post_edited")
          payload = JSON.parse(job_args["payload"])
          expect(payload["raw"]).to eq("edited body")
        end
      end

      it "rejects stale title and tag edits and skips an unchanged category" do
        put "/t/#{topic.slug}/#{topic.id}.json",
            params: {
              title: "brand new title",
              original_title: "another title",
            }

        expect(response.status).to eq(409)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("edit_conflict"))

        put "/t/#{topic.slug}/#{topic.id}.json",
            params: {
              tags: %w[tag1 tag2],
              original_tags: %w[tag3 tag4],
            }

        expect(response.status).to eq(409)
        expect(response.parsed_body["errors"].first).to eq(I18n.t("edit_conflict"))

        expect do
          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: topic.category_id }
        end.not_to change(PostRevision.all, :count)

        expect(response.status).to eq(200)
      end

      it "throws an error if it could not be saved" do
        PostRevisor.any_instance.stubs(:should_revise?).returns(false)
        put "/t/#{topic.slug}/#{topic.id}.json", params: { title: "brand new title" }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("activerecord.errors.models.topic.attributes.base.unable_to_update"),
        )
      end

      it "can update a topic to an uncategorized topic" do
        topic.update!(category: category)

        put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: "" }

        expect(response.status).to eq(200)
        expect(topic.reload.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      it "allows update on short non-slug url" do
        put "/t/#{topic.id}.json", params: { title: "This is a new title for the topic" }

        topic.reload
        expect(topic.title).to eq("This is a new title for the topic")
      end

      it "returns errors when the rate limit is exceeded" do
        EditRateLimiter.any_instance.expects(:performed!).raises(RateLimiter::LimitExceeded.new(60))

        put "/t/#{topic.slug}/#{topic.id}.json",
            params: {
              title: "This is a new title for the topic",
            }

        expect(response.status).to eq(429)
      end

      describe "when first post is locked" do
        it "requires staff to edit a locked first post, even with edit-all groups" do
          SiteSetting.edit_all_topic_groups = Group::AUTO_GROUPS[:trust_level_3]
          SiteSetting.edit_all_post_groups = Group::AUTO_GROUPS[:trust_level_4]
          user.update!(trust_level: 3)
          topic.first_post.update!(locked_by_id: admin.id)

          put "/t/#{topic.slug}/#{topic.id}.json", params: { title: topic.title + " hello" }

          expect(response.status).to eq(403)

          sign_in(admin)

          put "/t/#{topic.slug}/#{topic.id}.json", params: { title: topic.title + " hello" }
          expect(response.status).to eq(200)
        end
      end

      context "with tags" do
        before { SiteSetting.tagging_enabled = true }

        describe "tagging by name" do
          it "adds, creates, and removes tags by name, skipping revisions for unchanged tags" do
            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: [tag.name] }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.tags.pluck(:id)).to contain_exactly(tag.id)

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: [tag.name] }
            end.not_to change { topic.reload.first_post.revisions.count }

            expect(response.status).to eq(200)

            SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
            original_category_id = topic.category_id

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: [tag.name, "newtag"] }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.reload.tags.pluck(:name)).to contain_exactly(tag.name, "newtag")
            expect(topic.category_id).to eq(original_category_id)

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: [""] }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.tags).to eq([])
          end

          it "can change the category and create a new tag" do
            SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
            expect do
              put "/t/#{topic.slug}/#{topic.id}.json",
                  params: {
                    tags: ["newtag"],
                    category_id: category.id,
                  }
            end.to change { topic.reload.first_post.revisions.count }.by(1)

            expect(response.status).to eq(200)
            expect(topic.reload.tags.pluck(:name)).to contain_exactly("newtag")
            expect(topic.category_id).to eq(category.id)
          end

          it "can add a tag to wiki topic" do
            SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
            topic.first_post.update!(wiki: true)
            sign_in(user_2)

            expect do
              put "/t/#{topic.id}/tags.json", params: { tags: [tag.name] }
            end.not_to change { topic.reload.first_post.revisions.count }

            expect(response.status).to eq(403)
            user_2.groups << Group.find_by(name: "trust_level_2")

            expect do put "/t/#{topic.id}/tags.json", params: { tags: [tag.name] } end.to change {
              topic.reload.first_post.revisions.count
            }.by(1)

            expect(response.status).to eq(200)
            expect(topic.tags.pluck(:id)).to contain_exactly(tag.id)
          end
        end

        it "validates tag limits and accepts empty, object-array, indexed-hash, and new-tag parameters" do
          expect(topic.tags).to be_empty

          put "/t/#{topic.id}/tags.json"

          expect(response.status).to eq(200)
          expect(response.parsed_body["errors"]).to be_nil

          SiteSetting.max_tags_per_topic = 1

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                tags: [{ id: tag.id, name: tag.name }, {}],
              },
              as: :json

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to contain_exactly(
            I18n.t("tags.too_many_tags_for_topic", count: 1),
          )
          expect(topic.reload.tags).to be_empty

          expect do
            put "/t/#{topic.id}/tags.json", params: { tags: [{ id: tag.id, name: tag.name }] }
          end.to change { topic.reload.first_post.revisions.count }.by(1)

          expect(response.status).to eq(200)
          expect(topic.tags.pluck(:id)).to contain_exactly(tag.id)

          topic.tags.clear

          expect do
            put "/t/#{topic.id}/tags.json",
                params: {
                  tags: {
                    "0" => {
                      id: tag.id,
                      name: tag.name,
                    },
                  },
                }
          end.to change { topic.reload.first_post.revisions.count }.by(1)

          expect(response.status).to eq(200)
          expect(topic.tags.pluck(:id)).to contain_exactly(tag.id)

          SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]

          expect do
            put "/t/#{topic.id}/tags.json", params: { tags: [{ name: "brand-new" }] }
          end.to change { topic.reload.first_post.revisions.count }.by(1)

          expect(response.status).to eq(200)
          expect(topic.reload.tags.pluck(:name)).to contain_exactly("brand-new")
        end

        context "with tag synonyms" do
          fab!(:canonical) { Fabricate(:tag, name: "apple-inc") }
          fab!(:aapl) { Fabricate(:tag, name: "aapl", target_tag: canonical) }
          fab!(:appl) { Fabricate(:tag, name: "appl", target_tag: canonical) }

          it "canonicalizes synonyms and skips unchanged revisions on both update routes" do
            put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: %w[aapl appl apple-inc] }

            expect(response.status).to eq(200)
            expect(response.parsed_body["tags"].map { |t| t["name"] }).to contain_exactly(
              "apple-inc",
            )
            expect(topic.reload.tags.pluck(:name)).to contain_exactly("apple-inc")

            expect do
              put "/t/#{topic.slug}/#{topic.id}.json",
                  params: {
                    tags: [
                      { id: aapl.id, name: "aapl" },
                      { id: appl.id, name: "appl" },
                      { id: canonical.id, name: "apple-inc" },
                    ],
                  }
            end.not_to change { topic.reload.first_post.revisions.count }

            expect(response.status).to eq(200)
            expect(response.parsed_body["tags"].map { |t| t["name"] }).to contain_exactly(
              "apple-inc",
            )

            expect do
              put "/t/#{topic.id}/tags.json",
                  params: {
                    tags: [
                      { id: aapl.id, name: "aapl" },
                      { id: appl.id, name: "appl" },
                      { id: canonical.id, name: "apple-inc" },
                    ],
                  }
            end.not_to change { topic.reload.first_post.revisions.count }

            expect(response.status).to eq(200)
            expect(response.parsed_body["tags"].map { |t| t["name"] }).to contain_exactly(
              "apple-inc",
            )
          end
        end

        it "updates object tags and records revisions only for changes" do
          SiteSetting.create_tag_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
          topic.tags << tag

          expect do
            put "/t/#{topic.slug}/#{topic.id}.json",
                params: {
                  tags: [{ id: tag.id, name: tag.name }, { name: "new-tag" }],
                }
          end.to change { topic.reload.first_post.revisions.count }.by(1)

          expect(response.status).to eq(200)
          expect(topic.reload.tags.pluck(:name)).to contain_exactly(tag.name, "new-tag")

          expect do
            put "/t/#{topic.slug}/#{topic.id}.json",
                params: {
                  tags: [{ id: tag.id, name: tag.name }],
                }
          end.to change { topic.reload.first_post.revisions.count }.by(1)

          expect(response.status).to eq(200)
          expect(topic.reload.tags).to contain_exactly(tag)

          expect do
            put "/t/#{topic.slug}/#{topic.id}.json",
                params: {
                  tags: [{ id: tag.id, name: tag.name }],
                }
          end.not_to change { topic.reload.first_post.revisions.count }

          expect(response.status).to eq(200)

          expect do put "/t/#{topic.slug}/#{topic.id}.json" end.to_not change {
            topic.reload.tags.count
          }

          expect(response.status).to eq(200)

          expect do
            put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: [] }, as: :json
          end.to change { topic.reload.first_post.revisions.count }.by(1)

          expect(response.status).to eq(200)
          expect(topic.reload.tags).to be_empty

          expect do
            put "/t/#{topic.slug}/#{topic.id}.json", params: { tags: [] }, as: :json
          end.not_to change { topic.reload.first_post.revisions.count }

          expect(response.status).to eq(200)
        end
      end

      context "when topic is private" do
        before do
          topic.update!(
            archetype: Archetype.private_message,
            category: nil,
            allowed_users: [topic.user],
          )
        end

        context "when there are no changes" do
          it "skips revisions when the private message is unchanged" do
            expect do
              put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: topic.category_id }
            end.not_to change(PostRevision.all, :count)

            expect(response.status).to eq(200)
          end
        end
      end

      context "when updating to a category with restricted tags" do
        fab!(:restricted_category) { Fabricate(:category, user: post_author1) }
        fab!(:tag1, :tag)
        fab!(:tag2, :tag)
        fab!(:tag3, :tag)
        fab!(:tag_group_1) { Fabricate(:tag_group, tag_names: [tag1.name]) }
        fab!(:tag_group_2, :tag_group)

        fab!(:topic_tag) do
          topic.update!(tags: [tag1])
          topic.topic_tags.find_by!(tag_id: tag1.id)
        end

        before { SiteSetting.tagging_enabled = true }

        it "rejects categories disallowing current tags directly or through tag groups" do
          restricted_category.allowed_tags = [tag2.name]

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

          result = response.parsed_body

          expect(response.status).to eq(422)
          expect(result["errors"]).to be_present
          expect(topic.reload.category_id).not_to eq(restricted_category.id)

          restricted_category.allowed_tags = []
          tag_group_2.tags = [tag2]
          restricted_category.allowed_tag_groups = [tag_group_2.name]

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

          result = response.parsed_body

          expect(response.status).to eq(422)
          expect(result["errors"]).to be_present
          expect(topic.reload.category_id).not_to eq(restricted_category.id)
        end

        it "can change to a category allowing this topic current tags" do
          restricted_category.allowed_tags = [tag1.name]

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

          expect(response.status).to eq(200)
        end

        it "can change to a category allowing this topic current tags (through tag_group)" do
          tag_group_1.tags = [tag1]
          restricted_category.allowed_tag_groups = [tag_group_1.name]

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

          expect(response.status).to eq(200)
        end

        it "can change to a category allowing any tag" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(200)
        end

        it "can’t add a category-only tags from another category to a category" do
          restricted_category.allowed_tags = [tag2.name]

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                tags: [tag2.name],
                category_id: category.id,
              }

          result = response.parsed_body
          expect(response.status).to eq(422)
          expect(result["errors"]).to be_present
          expect(result["errors"][0]).to include(tag2.name)
          expect(topic.reload.category_id).not_to eq(restricted_category.id)
        end

        it "allows category change when topic has a hidden tag" do
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag1.name])

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(200)
          expect(topic.reload.tags).to include(tag1)
        end

        it "does not reveal a hidden current tag when a category change is rejected" do
          hidden_tag = Fabricate(:tag)
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [hidden_tag.name])
          topic.update!(tags: [hidden_tag])
          restricted_category.allowed_tags = [tag2.name]

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: restricted_category.id }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"].first).not_to include(hidden_tag.name)
        end

        it "allows category change when topic has a read-only tag" do
          Fabricate(
            :tag_group,
            permissions: {
              "staff" => 1,
              "everyone" => 3,
            },
            tag_names: [tag3.name],
          )
          topic.update!(tags: [tag3])

          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(200)
          expect(topic.reload.tags).to contain_exactly(tag3)
        end

        it "does not leak tag name when trying to use a staff tag" do
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag3.name])

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                tags: [tag3.name],
                category_id: category.id,
              }

          result = response.parsed_body
          expect(response.status).to eq(422)
          expect(result["errors"]).to be_present
          expect(result["errors"][0]).not_to include(tag3.name)
        end

        it "does not resolve hidden tags sent by ID" do
          Fabricate(:tag_group, permissions: { "staff" => 1 }, tag_names: [tag3.name])
          restricted_category.allowed_tags = [tag2.name]

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                tags: [{ id: tag2.id, name: tag2.name }, { id: tag3.id, name: "anything" }],
                category_id: restricted_category.id,
              }

          expect(response.status).to eq(200)
          expect(topic.reload.tags.map(&:name)).not_to include(tag3.name)
        end

        it "cleans tag parameters" do
          restricted_category.allowed_tags = [tag2.name]

          put "/t/#{topic.slug}/#{topic.id}.json",
              params: {
                tags: [""],
                category_id: restricted_category.id,
              }

          expect(response.status).to eq(200)
        end

        context "with content localization enabled" do
          fab!(:tag_localization) do
            Fabricate(:tag_localization, tag: tag1, locale: "ja", name: "タグ1")
          end

          before do
            SiteSetting.content_localization_enabled = true
            SiteSetting.content_localization_supported_locales = "en|ja"
            tag1.update!(locale: "en")
            user.update!(locale: "ja")
          end

          it "accepts localized tag objects and string tags when changing category" do
            restricted_category.allowed_tags = [tag1.name]

            put "/t/#{topic.slug}/#{topic.id}.json",
                params: {
                  tags: [{ id: tag1.id, name: "タグ1" }],
                  category_id: restricted_category.id,
                }

            expect(response.status).to eq(200)

            topic.update!(category_id: SiteSetting.uncategorized_category_id)

            put "/t/#{topic.slug}/#{topic.id}.json",
                params: {
                  tags: [tag1.name],
                  category_id: restricted_category.id,
                }

            expect(response.status).to eq(200)
          end

          it "can edit tags with localized tag names" do
            tag2 = Fabricate(:tag, name: "planning", locale: "en")
            Fabricate(:tag_localization, tag: tag2, locale: "ja", name: "計画")

            put "/t/#{topic.slug}/#{topic.id}.json",
                params: {
                  tags: [{ id: tag1.id, name: "タグ1" }, { id: tag2.id, name: "計画" }],
                }

            expect(response.status).to eq(200)
            expect(topic.reload.tags).to contain_exactly(tag1, tag2)
          end
        end
      end

      context "when allow_uncategorized_topics is false" do
        before { SiteSetting.allow_uncategorized_topics = false }

        it "can add a category to an uncategorized topic" do
          put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(200)
          expect(topic.reload.category).to eq(category)
        end
      end

      it "can not clear the category when the guardian disallows the move" do
        topic.update!(category:)
        Guardian.any_instance.stubs(:can_move_topic_to_category?).returns(false)

        put "/t/#{topic.slug}/#{topic.id}.json", params: { category_id: nil }, as: :json

        expect(response.status).to eq(403)
        expect(topic.reload.category_id).to eq(category.id)
      end
    end

    describe "featured links" do
      fab!(:link_topic) { Fabricate(:topic, user: trust_level_1) }
      fab!(:link_post) { Fabricate(:post, user: post_author1, topic: link_topic) }

      before { sign_in(trust_level_1) }

      it "allows featured link edits only when enabled site-wide and for the category" do
        put "/t/#{link_topic.slug}/#{link_topic.id}.json",
            params: {
              featured_link: "https://discourse.org",
            }

        expect(response.status).to eq(200)
        expect(link_topic.reload.featured_link).to eq("https://discourse.org")

        put "/t/#{link_topic.slug}/#{link_topic.id}.json", params: { featured_link: nil }

        expect(response.status).to eq(200)
        expect(link_topic.reload.featured_link).to be_nil

        SiteSetting.topic_featured_link_enabled = false

        put "/t/#{link_topic.slug}/#{link_topic.id}.json",
            params: {
              featured_link: "https://discourse.org",
            }

        expect(response.status).to eq(422)
        expect(link_topic.reload.featured_link).to be_nil

        SiteSetting.topic_featured_link_enabled = true
        category.update!(topic_featured_link_allowed: false)
        link_topic.update!(category: category)

        put "/t/#{link_topic.slug}/#{link_topic.id}.json",
            params: {
              featured_link: "https://discourse.org",
            }

        expect(response.status).to eq(422)
        expect(link_topic.reload.featured_link).to be_nil

        link_topic.update!(
          category_id: SiteSetting.uncategorized_category_id,
          featured_link: "https://discourse.org",
        )

        put "/t/#{link_topic.slug}/#{link_topic.id}.json",
            params: {
              category_id: category.id,
              featured_link: nil,
            }

        expect(response.status).to eq(200)
        expect(link_topic.reload.category_id).to eq(category.id)
        expect(link_topic.featured_link).to be_nil
      end

      it "requires permission to set a link but allows a blank link in other edits" do
        link_topic.update!(user: trust_level_0)
        sign_in(trust_level_0)

        put "/t/#{link_topic.slug}/#{link_topic.id}.json",
            params: {
              featured_link: "https://discourse.org",
            }

        expect(response.status).to eq(422)
        expect(link_topic.reload.featured_link).to be_nil

        put "/t/#{link_topic.slug}/#{link_topic.id}.json",
            params: {
              title: "A brand new title for this topic",
              featured_link: nil,
            }

        expect(response.status).to eq(200)
        expect(link_topic.reload.title).to eq("A brand new title for this topic")
      end
    end
  end

  describe "#show_by_external_id" do
    fab!(:private_topic) do
      Fabricate(
        :private_message_topic,
        external_id: "private",
        user: post_author1,
        recipient: post_author2,
      )
    end
    fab!(:topic) { Fabricate(:topic, external_id: "asdf", user: post_author1) }

    it "redirects matching external IDs and returns 404 for missing IDs" do
      get "/t/external_id/asdf.json"
      expect(response.status).to eq(301)
      expect(response).to redirect_to(topic.relative_url + ".json")

      get "/t/external_id/fdsa.json"
      expect(response.status).to eq(404)
    end

    it "preserves allowed query parameters and omits invalid or zero-valued parameters" do
      get "/t/external_id/asdf.json", params: { filter_top_level_replies: true }
      expect(response.status).to eq(301)
      expect(response).to redirect_to("#{topic.relative_url}.json?filter_top_level_replies=true")

      get "/t/external_id/asdf.json", params: { not_valid: true }
      expect(response.status).to eq(301)
      expect(response).to redirect_to(topic.relative_url + ".json")

      get "/t/external_id/asdf.json", params: { filter_top_level_replies: true, post_number: 9999 }
      expect(response.status).to eq(301)
      expect(response).to redirect_to(
        "#{topic.relative_url}/9999.json?filter_top_level_replies=true",
      )

      get "/t/external_id/asdf.json",
          params: {
            filter_top_level_replies: true,
            print: true,
            preview_theme_id: 9999,
            preview_color_scheme_id: 1,
            preview_dark_color_scheme_id: 2,
            include_raw: true,
          }
      expect(response.status).to eq(301)
      expect(response).to redirect_to(
        "#{topic.relative_url}.json?print=true&filter_top_level_replies=true&preview_theme_id=9999&preview_color_scheme_id=1&preview_dark_color_scheme_id=2&include_raw=true",
      )

      get "/t/external_id/asdf.json", params: { page: "0" }
      expect(response).to redirect_to("#{topic.relative_url}.json")

      get "/t/external_id/asdf.json", params: { page: "00" }
      expect(response).to redirect_to("#{topic.relative_url}.json")

      get "/t/external_id/asdf.json", params: { page: "abc" }
      expect(response).to redirect_to("#{topic.relative_url}.json")
    end

    describe "when user does not have access to the topic" do
      it "returns a not-found response" do
        sign_in(user)

        get "/t/external_id/private.json"

        expect(response.status).to eq(403)
        expect(response.body).to include(I18n.t("invalid_access"))
      end
    end
  end

  describe "#show" do
    fab!(:private_topic) { pm }
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    it "serves a cached public topic after a restricted category move until its 60-second TTL expires" do
      global_setting :anon_cache_store_threshold, 1
      Middleware::AnonymousCache.enable_anon_cache
      Middleware::AnonymousCache.clear_all_cache!
      url = "#{topic.relative_url}.json"
      cooked = topic.first_post.cooked

      get url

      expect(response.status).to eq(200)
      expect(response.headers["X-Discourse-Cached"]).to eq("store")
      expect(response.parsed_body["post_stream"]["posts"].first["cooked"]).to eq(cooked)

      cache = Middleware::AnonymousCache::Helper.new(request.env)
      cache_keys = [cache.cache_key_body, cache.cache_key_other]
      cache_keys.each { |key| expect(Discourse.redis.ttl(key)).to be_between(59, 60) }

      topic.change_category_to_id(staff_category.id)

      get url

      expect(response.status).to eq(200)
      expect(response.headers["X-Discourse-Cached"]).to eq("true")
      expect(response.parsed_body["post_stream"]["posts"].first["cooked"]).to eq(cooked)

      # Redis uses its own clock, so simulate expiry after checking the real TTL.
      cache_keys.each { |key| Discourse.redis.expire(key, 0) }

      get url

      expect(response.status).to eq(404)
      expect(response.headers["X-Discourse-Cached"]).not_to eq("true")
      expect(response.parsed_body["post_stream"]).to be_nil
    ensure
      Middleware::AnonymousCache.clear_all_cache!
    end

    describe "when topic is not allowed" do
      it "returns a not-found response" do
        SiteSetting.detailed_404 = true
        sign_in(user)

        get "/t/#{private_topic.id}.json"

        expect(response.status).to eq(403)
        expect(response.body).to include(I18n.t("invalid_access"))
      end

      it "removes only the notifications of the refused topic" do
        refused_notification = Fabricate(:notification, user:, topic: private_topic)
        other_notifications = [
          Fabricate(:notification, user:, topic:),
          Fabricate(:notification, user:, topic: nil),
        ]
        sign_in(user)

        get "/t/#{private_topic.id}.json", params: { topic_id: topic.id }
        get "/t/#{private_topic.id}.json"

        expect(response.status).to eq(404)
        expect(Notification.exists?(refused_notification.id)).to eq(false)
        expect(Notification.where(id: other_notifications.map(&:id)).count).to eq(2)
      end
    end

    describe "when topic is allowed to a group" do
      fab!(:group) { Fabricate(:group, public_admission: true) }
      fab!(:category) { Fabricate(:private_category, group: group, user: post_author1) }
      fab!(:topic) { Fabricate(:topic, category: category, user: post_author1) }

      before { SiteSetting.detailed_404 = true }

      it "shows a descriptive error message containing the group name" do
        get "/t/#{topic.id}.json"

        extras = response.parsed_body["extras"]
        html = CGI.unescapeHTML(extras["html"])
        expect(response.status).to eq(403)
        expect(extras["title"]).to eq(I18n.t("page_forbidden.page_title"))
        expect(html).to include(I18n.t("not_in_group.title_topic", group: group.name))
        expect(html).to include(I18n.t("not_in_group.join_group"))

        get "/t/#{topic.id}"
        expect(response).to have_http_status(:forbidden)
        expect(css_select("title").text).to include(I18n.t("page_forbidden.page_title"))
      end
    end

    it "correctly renders canonicals" do
      get "/t/#{topic.id}", params: { slug: topic.slug }

      expect(response.status).to eq(200)
      expect(css_select("link[rel=canonical]").length).to eq(1)
      expect(response.headers["Cache-Control"]).to eq("no-cache, no-store")
    end

    it "returns 301 even if slug does not match URL" do
      # in the past we had special logic for unlisted topics
      # we would require slug unless you made a json call
      # this was not really providing any security
      #
      # we no longer require a topic be visible to perform url correction
      # if you need to properly hide a topic for users use a secure category
      # or a PM
      Fabricate(:post, user: post_author1, topic: invisible_topic)

      get "/t/#{invisible_topic.id}.json", params: { slug: invisible_topic.slug }
      expect(response.status).to eq(200)

      get "/t/#{topic.id}.json", params: { slug: "just-guessing" }
      expect(response.status).to eq(301)

      get "/t/#{topic.slug}.json"
      expect(response.status).to eq(301)
    end

    it "returns the public topic without recording a view or an incoming link" do
      expect do get "/t/#{topic.slug}/#{topic.id}.json" end.not_to change {
        [TopicViewItem.count, IncomingLink.count]
      }

      expect(response.status).to eq(200)
      expect(response.headers["X-Robots-Tag"]).to be_nil
      expect(response.headers["Discourse-Readonly"]).to be_nil
    end

    it "does not expose private message tag descriptions when the viewer cannot see tags" do
      SiteSetting.tagging_enabled = true
      SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:admins].to_s
      pm_post = Fabricate(:private_message_post, user: admin, recipient: user)
      pm_topic = pm_post.topic
      pm_tag = Fabricate(:tag, name: "secret-pm-tag", description: "secret PM tag description")
      pm_topic.tags << pm_tag

      sign_in(user)
      get "/t/#{pm_topic.slug}/#{pm_topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).not_to have_key("tags")
      expect(response.parsed_body).not_to have_key("tags_descriptions")
    end

    it "does not expose tags restricted to inaccessible categories" do
      SiteSetting.tagging_enabled = true
      public_tag = Fabricate(:tag, name: "public-tag", description: "public tag description")
      restricted_tag =
        Fabricate(:tag, name: "restricted-tag", description: "restricted tag description")
      topic.tags = [public_tag, restricted_tag]
      private_category = Fabricate(:private_category, group: Group[:staff])
      private_category.tags = [restricted_tag]

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["tags"].map { |tag| tag["name"] }).to contain_exactly(
        public_tag.name,
      )
      expect(response.parsed_body["tags_descriptions"]).to eq(
        { public_tag.name => public_tag.description },
      )

      sign_in(admin)
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["tags"].map { |tag| tag["name"] }).to contain_exactly(
        public_tag.name,
        restricted_tag.name,
      )
      expect(response.parsed_body["tags_descriptions"]).to eq(
        public_tag.name => public_tag.description,
        restricted_tag.name => restricted_tag.description,
      )
    end

    it "does not expose links from hidden posts in topic details to non-staff viewers" do
      test_topic = Fabricate(:topic, user: post_author1)
      visible_post = Fabricate(:post, topic: test_topic, user: post_author1)
      hidden_post = Fabricate(:post, topic: test_topic, user: post_author1)

      Fabricate(
        :topic_link,
        post: visible_post,
        url: "https://visible-link.example.com",
        domain: "visible-link.example.com",
        clicks: 1,
        title: "Visible title",
      )
      Fabricate(
        :topic_link,
        post: hidden_post,
        url: "https://hidden-link.example.com",
        domain: "hidden-link.example.com",
        clicks: 1,
        title: "Hidden title",
      )

      hidden_post.hide!(PostActionType.types[:off_topic])

      get "/t/#{test_topic.slug}/#{test_topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["details"]["links"]).to contain_exactly(
        a_hash_including("url" => "https://visible-link.example.com", "title" => "Visible title"),
      )

      sign_in(moderator)
      get "/t/#{test_topic.slug}/#{test_topic.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["details"]["links"]).to contain_exactly(
        a_hash_including("url" => "https://visible-link.example.com", "title" => "Visible title"),
        a_hash_including("url" => "https://hidden-link.example.com", "title" => "Hidden title"),
      )
    end

    it "does not expose links from unlisted topics to anonymous viewers" do
      public_post = Fabricate(:post, user: post_author1)
      public_topic = public_post.topic
      public_source_topic = Fabricate(:topic, user: post_author1, title: "Public source topic")
      public_source_post =
        Fabricate(
          :post,
          topic: public_source_topic,
          user: post_author1,
          raw:
            "#{Discourse.base_url_no_prefix}#{public_topic.relative_url(public_post.post_number)}",
        )
      unlisted_source_topic = Fabricate(:topic, user: post_author1, title: "Unlisted source topic")
      unlisted_source_post =
        Fabricate(
          :post,
          topic: unlisted_source_topic,
          user: post_author1,
          raw:
            "#{Discourse.base_url_no_prefix}#{public_topic.relative_url(public_post.post_number)}",
        )

      TopicLink.extract_from(public_source_post)
      TopicLink.extract_from(unlisted_source_post)
      unlisted_source_topic.update_column(:visible, false)

      get "/t/#{public_topic.slug}/#{public_topic.id}.json"

      expect(response).to have_http_status(:ok)
      serialized_public_post =
        response
          .parsed_body
          .dig("post_stream", "posts")
          .find { |post| post["id"] == public_post.id }
      expect(serialized_public_post["link_counts"]).to contain_exactly(
        a_hash_including(
          "url" =>
            "#{Discourse.base_url_no_prefix}#{public_source_topic.relative_url(public_source_post.post_number)}",
          "title" => public_source_topic.title,
        ),
      )
    end

    it "does not expose linkbacks from hidden or whisper source posts to non-staff viewers" do
      SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s

      public_post = Fabricate(:post, user: post_author1)
      public_topic = public_post.topic
      link_url =
        "#{Discourse.base_url_no_prefix}#{public_topic.relative_url(public_post.post_number)}"

      visible_source_topic = Fabricate(:topic, user: post_author1, title: "Visible source topic")
      Fabricate(:post, topic: visible_source_topic, user: post_author1, raw: "op body")
      visible_source_post =
        Fabricate(:post, topic: visible_source_topic, user: post_author1, raw: link_url)

      hidden_source_topic = Fabricate(:topic, user: post_author1, title: "Hidden source topic")
      Fabricate(:post, topic: hidden_source_topic, user: post_author1, raw: "op body")
      hidden_source_post =
        Fabricate(:post, topic: hidden_source_topic, user: post_author1, raw: link_url)

      whisper_source_topic = Fabricate(:topic, user: post_author1, title: "Whisper source topic")
      Fabricate(:post, topic: whisper_source_topic, user: post_author1, raw: "op body")
      whisper_source_post =
        Fabricate(:post, topic: whisper_source_topic, user: post_author1, raw: link_url)

      TopicLink.extract_from(visible_source_post)
      TopicLink.extract_from(hidden_source_post)
      TopicLink.extract_from(whisper_source_post)

      hidden_source_post.hide!(PostActionType.types[:off_topic])
      whisper_source_post.update!(post_type: Post.types[:whisper])

      get "/t/#{public_topic.slug}/#{public_topic.id}.json"

      expect(response).to have_http_status(:ok)
      serialized_public_post =
        response.parsed_body.dig("post_stream", "posts").find { |p| p["id"] == public_post.id }
      expect(serialized_public_post["link_counts"].map { |l| l["title"] }).to contain_exactly(
        "Visible source topic",
      )

      sign_in(moderator)
      get "/t/#{public_topic.slug}/#{public_topic.id}.json"

      expect(response).to have_http_status(:ok)
      serialized_public_post =
        response.parsed_body.dig("post_stream", "posts").find { |p| p["id"] == public_post.id }
      expect(serialized_public_post["link_counts"].map { |l| l["title"] }).to contain_exactly(
        "Visible source topic",
        "Hidden source topic",
        "Whisper source topic",
      )
    end

    it "does not expose hidden post link counts", :aggregate_failures do
      first_post = Fabricate(:post, user: post_author1)
      test_topic = first_post.topic
      visible_post = Fabricate(:post, topic: test_topic, user: post_author1)
      hidden_post =
        Fabricate(
          :post,
          topic: test_topic,
          user: post_author1,
          hidden: true,
          hidden_reason_id: Post.hidden_reasons[:flag_threshold_reached],
        )

      visible_link =
        Fabricate(
          :topic_link,
          post: visible_post,
          url: "https://visible-link-count.example.com",
          domain: "visible-link-count.example.com",
          title: "Visible link count title",
        )
      hidden_link =
        Fabricate(
          :topic_link,
          post: hidden_post,
          url: "https://hidden-link-count.example.com",
          domain: "hidden-link-count.example.com",
          title: "Hidden link count title",
        )

      sign_in(user_2)

      get "/t/#{test_topic.slug}/#{test_topic.id}.json"

      expect(response.status).to eq(200)
      show_posts = response.parsed_body.dig("post_stream", "posts")
      show_hidden_post = show_posts.find { |post| post["id"] == hidden_post.id }
      show_visible_post = show_posts.find { |post| post["id"] == visible_post.id }
      expect(show_hidden_post).to include("hidden" => true, "can_see_hidden_post" => false)
      expect(show_hidden_post).not_to have_key("link_counts")
      expect(show_visible_post["link_counts"]).to contain_exactly(
        a_hash_including("url" => visible_link.url, "title" => visible_link.title),
      )
      expect(response.body).not_to include(hidden_link.url)

      get "/t/#{test_topic.id}/posts.json", params: { post_ids: [hidden_post.id, visible_post.id] }

      expect(response.status).to eq(200)
      posts = response.parsed_body.dig("post_stream", "posts")
      posts_hidden_post = posts.find { |post| post["id"] == hidden_post.id }
      posts_visible_post = posts.find { |post| post["id"] == visible_post.id }
      expect(posts_hidden_post).to include("hidden" => true, "can_see_hidden_post" => false)
      expect(posts_hidden_post).not_to have_key("link_counts")
      expect(posts_visible_post["link_counts"]).to contain_exactly(
        a_hash_including("url" => visible_link.url, "title" => visible_link.title),
      )
      expect(response.body).not_to include(hidden_link.url)
    end

    it "keeps the preview params when redirecting a short topic URL" do
      get "/t/#{topic.id}",
          params: {
            preview_theme_id: 9999,
            preview_base_font: "lora",
            preview_heading_font: "roboto",
            preview_component_ids: "12,13",
          }

      expect(response.status).to eq(301)
      expect(response).to redirect_to(
        "#{topic.relative_url}?preview_theme_id=9999&preview_base_font=lora&preview_heading_font=roboto&preview_component_ids=12%2C13",
      )
    end

    it "shows a blank-slug topic without redirecting" do
      topic.update_columns(title: "", slug: nil)
      topic.reload

      get "/t/#{topic.id}"

      expect(response.status).to eq(200)
    end

    context "with paginated posts" do
      fab!(:paginated_topic) { Fabricate(:topic, user: post_author1) }
      fab!(:posts) { Fabricate.times(2, :post, topic: paginated_topic, user: post_author1) }

      before { TopicView.stubs(:chunk_size).returns(2) }

      it "redirects over-range pages to the last page, preserving the locale" do
        Fabricate(:post, topic: paginated_topic, user: post_author1)
        Topic.reset_highest(paginated_topic.id)

        get paginated_topic.relative_url, params: { page: 5 }
        expect(response).to redirect_to("#{paginated_topic.relative_url}?page=2")

        get paginated_topic.relative_url, params: { :page => 5, Discourse::LOCALE_PARAM => "ja" }
        expect(response).to redirect_to(
          "#{paginated_topic.relative_url}?page=2&#{Discourse::LOCALE_PARAM}=ja",
        )
      end

      it "omits page one from redirects, preserving the locale" do
        get "#{topic.relative_url}.json", params: { page: 2 }
        expect(response).to redirect_to("#{topic.relative_url}.json")

        get topic.relative_url, params: { :page => 2, Discourse::LOCALE_PARAM => "ja" }
        expect(response).to redirect_to("#{topic.relative_url}?#{Discourse::LOCALE_PARAM}=ja")
      end

      it "uses the viewer-visible post count to find the last page" do
        SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
        Fabricate(:post, topic: paginated_topic, user: moderator, post_type: Post.types[:whisper])
        Topic.reset_highest(paginated_topic.id)

        get "#{paginated_topic.relative_url}.json", params: { page: 2 }
        expect(response).to redirect_to("#{paginated_topic.relative_url}.json")

        sign_in(admin)
        get "#{paginated_topic.relative_url}.json", params: { page: 2 }
        expect(response.status).to eq(200)
      end
    end

    it "redirects slug-only URLs, retaining only valid navigation parameters" do
      get "/t/#{topic.slug}"
      expect(response).to redirect_to(topic.relative_url)

      get "/t/#{topic.slug}", params: { post_number: 42 }
      expect(response).to redirect_to("#{topic.relative_url}/42")

      get "/t/#{topic.slug}", params: { post_number: 42, page: 123 }
      expect(response).to redirect_to("#{topic.relative_url}/42?page=123")

      get "/t/#{topic.slug}", params: { post_number: 42, page: [2] }
      expect(response).to redirect_to("#{topic.relative_url}/42?page=1")

      get "/t/#{topic.slug}", params: { silly_param: "hehe" }
      expect(response).to redirect_to(topic.relative_url)
    end

    it "resolves numeric-looking slugs before looking up a topic ID" do
      topic.update_column(:slug, "#{dest_topic.id}-reasons-discourse-is-awesome")

      get "/t/#{dest_topic.id}-reasons-discourse-is-awesome"

      expect(response).to redirect_to(topic.relative_url)
    end

    it "rejects arrays and nested objects as topic IDs" do
      get "/t/#{topic.id}/summary?id[]=a,b"
      expect(response.status).to eq(400)

      get "/t/#{topic.id}/summary?id[foo]=a"
      expect(response.status).to eq(400)
    end

    context "when nested replies are the default" do
      before do
        SiteSetting.nested_replies_enabled = true
        SiteSetting.nested_replies_default = true
      end

      it "keeps regular and embedded topics on the topic route" do
        get topic.relative_url
        expect(response.status).to eq(200)

        get topic.relative_url, params: { embed_mode: "true" }
        expect(response.status).to eq(200)

        get topic.relative_url, params: { embed_mode: "true", class_name: "lee-af" }
        expect(response.status).to eq(200)
      end

      it "keeps crawlers on the crawler layout" do
        get topic.relative_url, headers: { "HTTP_USER_AGENT" => "Googlebot" }

        expect(response.status).to eq(200)
        expect(response.body).to have_tag(:body, with: { class: "crawler" })
      end

      it "keeps private messages on the topic route" do
        Fabricate(:post, topic: pm, user: pm.user)
        sign_in(pm.user)

        get pm.relative_url

        expect(response.status).to eq(200)
        expect(response).not_to redirect_to("/n/#{pm.slug}/#{pm.id}")
      end
    end

    it "returns not found for unknown slugs, missing IDs, and IDs beyond database limits" do
      %w[
        /t/nope-nope.json
        /t/made-up-topic-slug/123456.json
        /t/made-up-topic-slug/5014217323220164041.json
      ].each do |path|
        get path
        expect(response.status).to eq(404), path
      end
    end

    it "doesn't use print mode when print equals false" do
      SiteSetting.max_prints_per_hour_per_user = 0

      get "/t/#{topic.slug}/#{topic.id}.json?print=false"
      expect(response.status).to eq(200)
    end

    it "does not result in N+1 queries problem when multiple topic participants have primary or flair group configured" do
      Group.user_trust_level_change!(post_author1.id, post_author1.trust_level)
      user2 = post_author2
      user3 = post_author3
      Fabricate(:post, topic: topic, user: user2)
      Fabricate(:post, topic: topic, user: user3)
      group = Fabricate(:group)
      user2.update!(primary_group: group)
      user3.update!(flair_group: group)

      # warm up
      get "/t/#{topic.id}.json"
      expect(response.status).to eq(200)

      first_request_queries =
        track_sql_queries do
          get "/t/#{topic.id}.json"

          expect(response.status).to eq(200)

          expect(
            response.parsed_body["details"]["participants"].map { |u| u["id"] },
          ).to contain_exactly(post_author1.id, user2.id, user3.id)
        end

      group2 = Fabricate(:group)
      user4 = post_author4
      user5 = post_author5
      user4.update!(flair_group: group2)
      user5.update!(primary_group: group2)
      Fabricate(:post, topic: topic, user: user4)
      Fabricate(:post, topic: topic, user: user5)

      second_request_queries =
        track_sql_queries do
          get "/t/#{topic.id}.json"

          expect(response.status).to eq(200)

          expect(
            response.parsed_body["details"]["participants"].map { |u| u["id"] },
          ).to contain_exactly(post_author1.id, user2.id, user3.id, user4.id, user5.id)
        end

      expect(second_request_queries.count).to eq(first_request_queries.count)
    end

    it "does not result in N+1 queries loading mentioned users" do
      SiteSetting.enable_user_status = true

      post =
        Fabricate(
          :post,
          raw:
            "post with many mentions: @#{user.username}, @#{user_2.username}, @#{admin.username}, @#{moderator.username}",
        )

      queries = track_sql_queries { get "/t/#{post.topic_id}.json" }

      user_statuses_queries = queries.filter { |q| q =~ /FROM "?user_statuses"?/ }
      expect(user_statuses_queries.size).to eq(2) # for current user and for all mentioned users

      user_options_queries = queries.filter { |q| q =~ /FROM "?user_options"?/ }
      expect(user_options_queries.size).to eq(1) # for all mentioned users
    end

    context "when content_localization_enabled true" do
      before do
        SiteSetting.content_localization_enabled = true
        SiteSetting.content_localization_allowed_groups = Group::AUTO_GROUPS[:everyone]
      end

      it "does not result in N+1 queries when loading a localized post" do
        3.times do
          Fabricate(
            :post_localization,
            post: Fabricate(:post, topic: topic, user: post_author1, locale: "ja"),
            locale: "en",
          )
        end

        queries =
          track_sql_queries do
            sign_in(admin)
            get "/t/#{topic.slug}/#{topic.id}.json"
          end

        queries = queries.filter { |q| q =~ /FROM "?post_localizations"?/ }
        expect(queries.size).to eq(1)
      end

      context "with an internal topic onebox" do
        fab!(:reader) { Fabricate(:user, locale: "ja") }
        fab!(:onebox_topic) do
          Fabricate(:topic, user: post_author1, title: "Sun Tzu's strategies", locale: "en")
        end
        fab!(:onebox_post) do
          Fabricate(
            :post,
            topic: onebox_topic,
            user: post_author1,
            post_number: 1,
            locale: "en",
            raw: "Subdue them.",
          )
        end
        fab!(:host_topic) { Fabricate(:topic, user: post_author1, locale: "ja") }
        fab!(:host_post) do
          Fabricate(
            :post,
            topic: host_topic,
            user: post_author1,
            post_number: 1,
            locale: "ja",
            raw: "見てください",
          )
        end

        fab!(:onebox_topic_localization) do
          Fabricate(:topic_localization, topic: onebox_topic, locale: "ja", title: "孫子の兵法")
        end
        fab!(:onebox_post_localization) do
          Fabricate(:post_localization, post: onebox_post, locale: "ja", cooked: "<p>戦わずして勝つ</p>")
        end
        fab!(:onebox_link) do
          TopicLink.create!(
            topic: host_topic,
            post: host_post,
            user: host_post.user,
            url: onebox_post.url,
            domain: Discourse.current_hostname,
            internal: true,
            quote: true,
            reflection: false,
            link_topic_id: onebox_topic.id,
            link_post_id: onebox_post.id,
          )
        end

        before do
          SiteSetting.allow_user_locale = true
          SiteSetting.content_localization_supported_locales = "en|ja"
        end

        def host_post_json
          get "/t/#{host_topic.id}.json"
          expect(response.status).to eq(200)
          response.parsed_body["post_stream"]["posts"].find { |p| p["id"] == host_post.id }
        end

        it "returns localized onebox data for a reader in their own language" do
          sign_in(reader)

          entry = host_post_json["localized_oneboxes"].first
          expect(entry["title"]).to eq("孫子の兵法")
          expect(entry["excerpt"]).to include("戦わずして勝つ")
        end

        it "omits localized onebox data when the reader disables automatic translation" do
          reader.user_option.update!(automatically_translate: false)
          sign_in(reader)

          expect(host_post_json.key?("localized_oneboxes")).to eq(false)
        end
      end
    end

    context "with serialize_post_user_badges" do
      fab!(:badge)
      before do
        theme = Fabricate(:theme)
        theme.theme_modifier_set.update!(serialize_post_user_badges: [badge.name])
        SiteSetting.default_theme_id = theme.id
      end

      it "correctly returns user badges that are registered" do
        first_post = topic.posts.order(:post_number).first
        first_post.user.user_badges.create!(
          badge_id: badge.id,
          granted_at: Time.zone.now,
          granted_by: Discourse.system_user,
        )

        expected_payload = {
          "users" => {
            first_post.user_id.to_s => {
              "id" => first_post.user.id,
              "badge_ids" => [badge.id],
            },
          },
          "badges" => {
            badge.id.to_s => {
              "id" => badge.id,
              "name" => badge.name,
              "slug" => badge.slug,
              "description" => badge.description,
              "icon" => badge.icon,
              "image_url" => badge.image_url,
              "badge_grouping_id" => badge.badge_grouping_id,
              "badge_type_id" => badge.badge_type_id,
            },
          },
        }

        get "/t/#{topic.slug}/#{topic.id}.json"
        user_badges = response.parsed_body["user_badges"]
        expect(user_badges).to eq(expected_payload)

        get "/t/#{topic.id}/posts.json?post_ids[]=#{first_post.id}"
        user_badges = response.parsed_body["user_badges"]
        expect(user_badges).to eq(expected_payload)
      end
    end

    it "keeps the locale param when redirecting to the correct slug" do
      get "/t/#{topic.slug}", params: { Discourse::LOCALE_PARAM => "ja" }

      expect(response).to redirect_to("#{topic.relative_url}?#{Discourse::LOCALE_PARAM}=ja")

      get "/t/wrong-slug/#{topic.id}", params: { Discourse::LOCALE_PARAM => "ja" }

      expect(response).to redirect_to("#{topic.relative_url}?#{Discourse::LOCALE_PARAM}=ja")
    end

    it "omits page zero when redirecting to the correct slug" do
      get "/t/wrong-slug/#{topic.id}", params: { page: 0 }

      expect(response).to redirect_to(topic.relative_url)
    end

    it "encodes the locale param when redirecting to the correct slug" do
      locale = "en，但他们的解决方案"

      get "/t/wrong-slug/#{topic.id}", params: { Discourse::LOCALE_PARAM => locale }

      expect(response).to have_http_status(:moved_permanently)
      expect(response.location).to eq(
        "#{Discourse.base_url}#{topic.relative_url}?#{Discourse::LOCALE_PARAM}=en%EF%BC%8C%E4%BD%86%E4%BB%96%E4%BB%AC%E7%9A%84%E8%A7%A3%E5%86%B3%E6%96%B9%E6%A1%88",
      )
    end

    context "with registered redirect_to_correct_topic_additional_query_parameters" do
      let(:modifier_block) { Proc.new { |allowed_params| allowed_params << :silly_param } }

      it "retains the permitted query param when redirecting" do
        plugin_instance = Plugin::Instance.new
        plugin_instance.register_modifier(
          :redirect_to_correct_topic_additional_query_parameters,
          &modifier_block
        )

        get "/t/#{topic.slug}", params: { silly_param: "hehe" }

        expect(response).to redirect_to("#{topic.relative_url}?silly_param=hehe")
      ensure
        DiscoursePluginRegistry.unregister_modifier(
          plugin_instance,
          :redirect_to_correct_topic_additional_query_parameters,
          &modifier_block
        )
      end
    end

    context "when a topic with nil slug exists" do
      before { dest_topic.update_column(:slug, nil) }

      it "returns a 404 when slug and topic id do not match a topic" do
        get "/t/made-up-topic-slug/123123.json"
        expect(response.status).to eq(404)
      end
    end

    context "with permission errors" do
      fab!(:allowed_user, :user)
      fab!(:allowed_group, :group)
      fab!(:accessible_group) { Fabricate(:group, public_admission: true) }
      fab!(:secure_category) { Fabricate(:private_category, group: allowed_group) }
      fab!(:allowed_membership) { Fabricate(:group_user, group: allowed_group, user: allowed_user) }
      fab!(:accessible_category) { Fabricate(:private_category, group: accessible_group) }
      fab!(:normal_topic) { Fabricate(:topic, user: post_author1) }
      fab!(:secure_topic) { Fabricate(:topic, user: post_author1, category: secure_category) }
      fab!(:private_topic) do
        Fabricate(:private_message_topic, user: allowed_user, recipient: post_author2)
      end

      fab!(:deleted_topic_id) { Fabricate(:deleted_topic, user: post_author1).id }
      fab!(:deleted_secure_topic_id) do
        Fabricate(:topic, user: post_author1, category: secure_category, deleted_at: 1.day.ago).id
      end
      fab!(:deleted_private_topic_id) do
        Fabricate(
          :private_message_topic,
          user: allowed_user,
          recipient: post_author2,
          deleted_at: 1.day.ago,
        ).id
      end

      let(:deleted_topic) { Topic.with_deleted.find(deleted_topic_id) }
      let(:deleted_secure_topic) { Topic.with_deleted.find(deleted_secure_topic_id) }
      let(:deleted_private_topic) { Topic.with_deleted.find(deleted_private_topic_id) }

      let!(:nonexistent_topic_id) { Topic.last.id + 10_000 }

      fab!(:secure_accessible_topic) do
        Fabricate(:topic, user: post_author1, category: accessible_category)
      end

      shared_examples "topic access responses" do |expected, request_json:|
        it "returns the expected access response for each topic URL" do
          format = request_json ? ".json" : ""

          actual =
            expected.to_h do |name, _status|
              path =
                if name == :nonexistent
                  "/t/garbage-slug/#{nonexistent_topic_id}#{format}"
                else
                  requested_topic = public_send(name)
                  "/t/#{requested_topic.slug}/#{requested_topic.id}#{format}"
                end

              get path
              [name, response.status]
            end

          expect(actual).to eq(expected)

          get "/t/#{secure_topic.slug}#{format}"
          expect(response.status).to eq(
            expected[:secure_topic] == 200 ? 301 : expected[:secure_topic],
          )
        end
      end

      context "without detailed error pages" do
        before { SiteSetting.detailed_404 = false }

        context "when anonymous" do
          expected = {
            normal_topic: 200,
            secure_topic: 404,
            private_topic: 404,
            deleted_topic: 404,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when anonymous with login required" do
          before { SiteSetting.login_required = true }

          expected = {
            normal_topic: 302,
            secure_topic: 302,
            private_topic: 302,
            deleted_topic: 302,
            deleted_secure_topic: 302,
            deleted_private_topic: 302,
            nonexistent: 302,
            secure_accessible_topic: 302,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when anonymous with login required, requesting json" do
          before { SiteSetting.login_required = true }

          expected = {
            normal_topic: 403,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 403,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 403,
            secure_accessible_topic: 403,
          }
          include_examples "topic access responses", expected, request_json: true
        end

        context "when normal user" do
          before { sign_in(user) }

          expected = {
            normal_topic: 200,
            secure_topic: 404,
            private_topic: 404,
            deleted_topic: 404,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when allowed user" do
          before { sign_in(allowed_user) }

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 404,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when moderator" do
          before { sign_in(moderator) }

          expected = {
            normal_topic: 200,
            secure_topic: 404,
            private_topic: 404,
            deleted_topic: 200,
            deleted_secure_topic: 404,
            deleted_private_topic: 404,
            nonexistent: 404,
            secure_accessible_topic: 404,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when admin" do
          before { sign_in(admin) }

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 200,
            deleted_secure_topic: 200,
            deleted_private_topic: 200,
            nonexistent: 404,
            secure_accessible_topic: 200,
          }
          include_examples "topic access responses", expected, request_json: false
        end
      end

      context "with detailed error pages" do
        before { SiteSetting.detailed_404 = true }

        context "when anonymous" do
          expected = {
            normal_topic: 200,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 410,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 404,
            secure_accessible_topic: 403,
          }
          include_examples "topic access responses", expected, request_json: true
        end

        context "when anonymous with login required" do
          before { SiteSetting.login_required = true }

          expected = {
            normal_topic: 302,
            secure_topic: 302,
            private_topic: 302,
            deleted_topic: 302,
            deleted_secure_topic: 302,
            deleted_private_topic: 302,
            nonexistent: 302,
            secure_accessible_topic: 302,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when normal user" do
          before { sign_in(user) }

          expected = {
            normal_topic: 200,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 410,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 404,
            secure_accessible_topic: 403,
          }
          include_examples "topic access responses", expected, request_json: true
        end

        context "when allowed user" do
          before { sign_in(allowed_user) }

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 410,
            deleted_secure_topic: 410,
            deleted_private_topic: 410,
            nonexistent: 404,
            secure_accessible_topic: 403,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when moderator" do
          before { sign_in(moderator) }

          expected = {
            normal_topic: 200,
            secure_topic: 403,
            private_topic: 403,
            deleted_topic: 200,
            deleted_secure_topic: 403,
            deleted_private_topic: 403,
            nonexistent: 404,
            secure_accessible_topic: 403,
          }
          include_examples "topic access responses", expected, request_json: false
        end

        context "when admin" do
          before { sign_in(admin) }

          expected = {
            normal_topic: 200,
            secure_topic: 200,
            private_topic: 200,
            deleted_topic: 200,
            deleted_secure_topic: 200,
            deleted_private_topic: 200,
            nonexistent: 404,
            secure_accessible_topic: 200,
          }
          include_examples "topic access responses", expected, request_json: false
        end
      end
    end

    it "records a view to invalid post_number" do
      expect do
        get "/t/#{topic.slug}/#{topic.id}/#{256**4}", params: { u: user.username }
        expect(response.status).to eq(200)
      end.to change { IncomingLink.count }.by(1)
    end

    it "records incoming links" do
      expect do get "/t/#{topic.slug}/#{topic.id}", params: { u: user.username } end.to change {
        IncomingLink.count
      }.by(1)
    end

    context "with print" do
      it "doesn't renders the print view when disabled" do
        SiteSetting.max_prints_per_hour_per_user = 0

        get "/t/#{topic.slug}/#{topic.id}/print"

        expect(response).to be_forbidden
      end

      it "renders the print view when enabled" do
        SiteSetting.max_prints_per_hour_per_user = 10
        get "/t/#{topic.slug}/#{topic.id}/print", headers: { HTTP_USER_AGENT: "Rails Testing" }

        expect(response.status).to eq(200)
        body = response.body

        expect(body).to have_tag(:body, class: "crawler")
        expect(body).to_not have_tag(:meta, with: { name: "fragment" })
      end

      it "uses the application layout when there's no param" do
        SiteSetting.max_prints_per_hour_per_user = 10
        get "/t/#{topic.slug}/#{topic.id}", headers: { HTTP_USER_AGENT: "Rails Testing" }

        body = response.body

        expect(body).to have_tag(:script, with: { "data-discourse-entrypoint" => "discourse" })
        expect(body).to have_tag(:meta, with: { name: "fragment" })
      end

      context "with restricted tags" do
        let(:tag_group) { Fabricate.build(:tag_group) }
        let(:tag_group_permission) { Fabricate.build(:tag_group_permission, tag_group: tag_group) }
        let(:restricted_tag) { Fabricate(:tag) }
        let(:public_tag) { Fabricate(:tag) }

        before do
          # avoid triggering a `before_create` callback in `TagGroup` which
          # messes with permissions
          tag_group.tag_group_permissions << tag_group_permission
          tag_group.save!
          tag_group_permission.tag_group.tags << restricted_tag
          topic.tags << [public_tag, restricted_tag]
        end

        it "doesn’t expose restricted tags" do
          get "/t/#{topic.slug}/#{topic.id}/print", headers: { HTTP_USER_AGENT: "Rails Testing" }
          expect(response.body).to match(public_tag.name)
          expect(response.body).not_to match(restricted_tag.name)
        end
      end
    end

    it "records the referer for a visit arriving via redirect" do
      get "/t/#{topic.id}", headers: { HTTP_REFERER: "http://twitter.com" }
      # Simulate browsers, which preserve Referer across same-origin redirects
      follow_redirect!(headers: { "HTTP_REFERER" => "http://twitter.com" })

      link = IncomingLink.first
      expect(link.referer).to eq("http://twitter.com")
    end

    it "tracks a visit for all html requests" do
      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}"
      topic_user = TopicUser.where(user: user, topic: topic).first
      expect(topic_user.last_visited_at).to eq_time(topic_user.first_visited_at)
    end

    context "when considering for a promotion" do
      before do
        SiteSetting.tl1_requires_topics_entered = 0
        SiteSetting.tl1_requires_read_posts = 0
        SiteSetting.tl1_requires_time_spent_mins = 0
      end

      it "reviews the user for a promotion if they're new" do
        sign_in(user)
        user.update_column(:trust_level, TrustLevel[0])
        get "/t/#{topic.slug}/#{topic.id}.json"
        user.reload
        expect(user.trust_level).to eq(1)
      end
    end

    context "with filters" do
      def extract_post_stream
        json = response.parsed_body
        json["post_stream"]["posts"].map { |post| post["id"] }
      end

      fab!(:replies) { Fabricate.times(3, :post, user: post_author1, topic: topic) }

      let(:post_ids) { [topic.first_post.id, *replies.map(&:id)] }

      before { TopicView.stubs(:chunk_size).returns(2) }

      it "grabs the correct set of posts" do
        get "/t/#{topic.slug}/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[0..1])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[0..1])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[2..3])

        post_number = topic.posts.pluck(:post_number).sort[3]
        get "/t/#{topic.slug}/#{topic.id}/#{post_number}.json"
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[-2..-1])

        TopicView.stubs(:chunk_size).returns(3)

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[0..2])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[3..3])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 3 }
        expect(response).to redirect_to("/t/#{topic.slug}/#{topic.id}.json?page=2")

        TopicView.stubs(:chunk_size).returns(4)

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 1 }
        expect(response.status).to eq(200)
        expect(extract_post_stream).to eq(post_ids[0..3])

        get "/t/#{topic.slug}/#{topic.id}.json", params: { page: 2 }
        expect(response).to redirect_to("/t/#{topic.slug}/#{topic.id}.json")
      end
    end

    context "with an external permalink on a soft-deleted topic" do
      before do
        topic.trash!(Discourse.system_user)
        Permalink.create!(
          url: "t/#{topic.slug}/#{topic.id}",
          external_url: "https://www.example.com",
        )
      end

      it "returns the external URL to XHR clients and redirects browsers" do
        [false, true].each do |detailed_errors|
          SiteSetting.detailed_404 = detailed_errors

          get "#{topic.relative_url}.json", headers: { "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest" }

          expect(response.status).to eq(200)
          expect(response.headers["Discourse-Xhr-Redirect"]).to eq("true")
          expect(response.body).to eq("https://www.example.com")
        end

        SiteSetting.detailed_404 = false
        get topic.relative_url

        expect(response.status).to eq(301)
        expect(response.headers["Location"]).to eq("https://www.example.com")
      end
    end

    context "with an external permalink on a nonexistent topic" do
      let(:nonexistent_topic_id) { Topic.maximum(:id) + 1 }

      before do
        Permalink.create!(
          url: "t/old-topic/#{nonexistent_topic_id}",
          external_url: "https://www.example.com",
        )
      end

      it "returns the external URL to XHR clients and redirects browsers" do
        get "/t/old-topic/#{nonexistent_topic_id}.json",
            headers: {
              "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest",
            }

        expect(response.status).to eq(200)
        expect(response.headers["Discourse-Xhr-Redirect"]).to eq("true")
        expect(response.body).to eq("https://www.example.com")

        get "/t/old-topic/#{nonexistent_topic_id}"

        expect(response.status).to eq(301)
        expect(response.headers["Location"]).to eq("https://www.example.com")
      end
    end

    context "with a branching reply tree" do
      fab!(:first_post) { Fabricate(:post, user: post_author1) }
      fab!(:topic) { first_post.topic }
      fab!(:root_reply) { Fabricate(:post, topic: topic, user: post_author2) }
      fab!(:direct_reply) do
        Fabricate(
          :post,
          topic: topic,
          user: post_author3,
          reply_to_post_number: root_reply.post_number,
        )
      end
      fab!(:sibling_reply) do
        Fabricate(
          :post,
          topic: topic,
          user: post_author4,
          reply_to_post_number: root_reply.post_number,
        )
      end
      fab!(:nested_reply) do
        Fabricate(
          :post,
          topic: topic,
          user: post_author5,
          reply_to_post_number: direct_reply.post_number,
        )
      end
      fab!(:other_root_reply) { Fabricate(:post, topic: topic, user: post_author5) }
      fab!(:other_child_reply) do
        Fabricate(
          :post,
          topic: topic,
          user: post_author4,
          reply_to_post_number: other_root_reply.post_number,
        )
      end
      fab!(:quote_reply) { Fabricate(:basic_reply, topic: topic, user: user) }
      fab!(:quoted_post_reply) do
        PostReply.create!(post_id: root_reply.id, reply_post_id: quote_reply.id)
      end

      it "returns direct and quoted replies without their descendants" do
        get "/t/#{topic.id}.json", params: { replies_to_post_number: root_reply.post_number }

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("suggested_topics")
        expect(response.parsed_body).not_to have_key("related_messages")
        expect(response.parsed_body["post_stream"]["posts"].map { |entry| entry["id"] }).to eq(
          [first_post, root_reply, direct_reply, sibling_reply, quote_reply].map(&:id),
        )
      end

      it "returns only top-level replies" do
        get "/t/#{topic.id}.json", params: { filter_top_level_replies: true }

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("suggested_topics")
        expect(response.parsed_body).not_to have_key("related_messages")
        expect(response.parsed_body["post_stream"]["posts"].map { |entry| entry["id"] }).to eq(
          [root_reply.id, other_root_reply.id],
        )
      end

      it "includes one ancestor and subsequent posts when filtering upwards" do
        get "/t/#{topic.id}.json", params: { filter_upwards_post_id: nested_reply.id }

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("suggested_topics")
        expect(response.parsed_body).not_to have_key("related_messages")
        expect(response.parsed_body["post_stream"]["posts"].map { |entry| entry["id"] }).to eq(
          [
            first_post,
            direct_reply,
            nested_reply,
            other_root_reply,
            other_child_reply,
            quote_reply,
          ].map(&:id),
        )
      end

      it "includes the configured number of ancestors when filtering upwards" do
        SiteSetting.max_reply_history = 2

        get "/t/#{topic.id}.json", params: { filter_upwards_post_id: nested_reply.id }

        expect(response.status).to eq(200)
        expect(response.parsed_body["post_stream"]["posts"].map { |entry| entry["id"] }).to eq(
          [
            first_post,
            root_reply,
            direct_reply,
            nested_reply,
            other_root_reply,
            other_child_reply,
            quote_reply,
          ].map(&:id),
        )
      end
    end

    context "when 'login required' site setting has been enabled" do
      before { SiteSetting.login_required = true }

      context "when the user is logged in" do
        before { sign_in(user) }

        it "shows the topic" do
          get "/t/#{topic.slug}/#{topic.id}.json"
          expect(response.status).to eq(200)
        end
      end

      context "when the user is not logged in" do
        let(:api_key) { Fabricate(:api_key, user: topic.user) }

        it "redirects browsers to the login page" do
          get "/t/#{topic.slug}/#{topic.id}"
          expect(response).to redirect_to login_path
        end

        it "raises a 403 for json requests" do
          get "/t/#{topic.slug}/#{topic.id}.json"
          expect(response.status).to eq(403)
        end

        it "shows the topic if valid api key is provided" do
          get "/t/#{topic.slug}/#{topic.id}.json", headers: { "HTTP_API_KEY" => api_key.key }

          expect(response.status).to eq(200)
          topic.reload
        end

        it "returns 403 for an invalid key" do
          %i[json html].each do |format|
            get "/t/#{topic.slug}/#{topic.id}.#{format}", headers: { "HTTP_API_KEY" => "bad" }

            expect(response.code.to_i).to eq(403)
            expect(response.body).to include(I18n.t("invalid_access"))
          end
        end
      end
    end

    it "is included for unlisted topics" do
      get "/t/#{invisible_topic.slug}/#{invisible_topic.id}.json"

      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    it "is included when allow_index_in_robots_txt is set to false" do
      SiteSetting.allow_index_in_robots_txt = false

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
    end

    describe "topic_noindex modifier" do
      fab!(:first_post) { Fabricate(:post, topic: topic, user: post_author1) }
      fab!(:second_post) { Fabricate(:post, topic: topic, user: post_author1) }

      let(:plugin) { Plugin::Instance.new }
      let(:modifier_args) { [] }
      let(:noindex_topic_ids) { [] }
      let(:modifier) do
        Proc.new do |noindex, modifier_topic|
          modifier_args << [noindex, modifier_topic]
          noindex || noindex_topic_ids.include?(modifier_topic.id)
        end
      end

      before { DiscoursePluginRegistry.register_modifier(plugin, :topic_noindex, &modifier) }
      after { DiscoursePluginRegistry.unregister_modifier(plugin, :topic_noindex, &modifier) }

      it "receives core's decision and the topic" do
        get "/t/#{topic.slug}/#{topic.id}.json"

        expect(response.status).to eq(200)
        expect(modifier_args).to eq([[false, topic]])
        expect(response.headers["X-Robots-Tag"]).to eq(nil)

        get "/t/#{invisible_topic.slug}/#{invisible_topic.id}.json"

        expect(response.status).to eq(200)
        expect(modifier_args.last).to eq([true, invisible_topic])
        expect(response.headers["X-Robots-Tag"]).to eq("noindex")
      end

      it "lets a plugin send noindex on every version of the topic page" do
        SiteSetting.enable_markdown_endpoints = true
        TopicView.stubs(:chunk_size).returns(1)
        noindex_topic_ids << topic.id

        [
          "/t/#{topic.slug}/#{topic.id}",
          "/t/#{topic.slug}/#{topic.id}?page=2",
          "/t/#{topic.slug}/#{topic.id}/2",
          "/t/#{topic.slug}/#{topic.id}/print",
          "/t/#{topic.slug}/#{topic.id}.json",
          "/t/#{topic.slug}/#{topic.id}.md",
        ].each do |path|
          get path, headers: { "HTTP_USER_AGENT" => "Googlebot" }

          expect(response.status).to eq(200), path
          expect(response.headers["X-Robots-Tag"]).to eq("noindex"), path
        end
      end

      it "keeps the site-wide nofollow when the site is not indexable" do
        SiteSetting.allow_index_in_robots_txt = false
        noindex_topic_ids << topic.id

        get "/t/#{topic.slug}/#{topic.id}.json"

        expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")

        get "/t/#{invisible_topic.slug}/#{invisible_topic.id}.json"

        expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")
      end
    end

    it "doesn't raise an error on a very long link" do
      get "/t/#{topic.id}.json", headers: { HTTP_REFERER: "http://#{"a" * 2000}.com" }
      expect(response.status).to eq(200)
    end

    context "when `enable_user_status` site setting is enabled" do
      fab!(:post) { Fabricate(:post, user: post_author1) }
      fab!(:topic) { post.topic }
      fab!(:post2) do
        Fabricate(
          :post,
          user: post_author2,
          topic: topic,
          raw: "I am mentioning @#{post_author1.username}.",
        )
      end

      before { SiteSetting.enable_user_status = true }

      it "does not return mentions when `enable_user_status` site setting is disabled" do
        SiteSetting.enable_user_status = false

        get "/t/#{topic.slug}/#{topic.id}.json"

        expect(response.status).to eq(200)

        json = response.parsed_body

        expect(json["post_stream"]["posts"][1]["mentioned_users"]).to eq(nil)
      end

      it "returns mentions with status" do
        post_author1.set_status!("off to dentist", "tooth")

        get "/t/#{topic.slug}/#{topic.id}.json"

        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["post_stream"]["posts"][1]["mentioned_users"].length).to be(1)

        mentioned_user = json["post_stream"]["posts"][1]["mentioned_users"][0]
        expect(mentioned_user["id"]).to be(post_author1.id)
        expect(mentioned_user["name"]).to eq(post_author1.name)
        expect(mentioned_user["username"]).to eq(post_author1.username)

        status = mentioned_user["status"]
        expect(status).to be_present
        expect(status["emoji"]).to eq(post_author1.user_status.emoji)
        expect(status["description"]).to eq(post_author1.user_status.description)
      end

      it "returns no mentioned users for plain text or unknown usernames" do
        plain_post =
          Fabricate(:post, user: post_author2, topic: topic, raw: "Post without mentions.")
        unknown_mention =
          Fabricate(:post, user: post_author2, topic: topic, raw: "Mentioning an @unexisting_user.")

        get "#{topic.relative_url}.json"

        expect(response.status).to eq(200)
        posts = response.parsed_body["post_stream"]["posts"].index_by { |entry| entry["id"] }
        expect(posts[plain_post.id]["mentioned_users"]).to eq([])
        expect(posts[unknown_mention.id]["mentioned_users"]).to eq([])
      end
    end

    it "uses escaped fragments only when the feature is enabled" do
      SiteSetting.enable_escaped_fragments = false
      get topic.relative_url, params: { _escaped_fragment_: "true" }

      expect(response.status).to eq(200)
      expect(response.body).to have_tag(
        :script,
        with: {
          "data-discourse-entrypoint" => "discourse",
        },
      )
      expect(response.body).not_to have_tag(:meta, with: { name: "fragment" })

      SiteSetting.enable_escaped_fragments = true
      get topic.relative_url

      expect(response.body).to have_tag(
        :script,
        with: {
          "data-discourse-entrypoint" => "discourse",
        },
      )
      expect(response.body).to have_tag(:meta, with: { name: "fragment" })

      get topic.relative_url,
          params: {
            _escaped_fragment_: true,
          },
          headers: {
            HTTP_USER_AGENT: "Rails Testing",
          }

      expect(response.status).to eq(200)
      expect(response.body).to have_tag(:body, with: { class: "crawler" })
      expect(response.body).not_to have_tag(:meta, with: { name: "fragment" })
    end

    describe "clear_notifications" do
      it "correctly clears notifications if specified via cookie" do
        set_subfolder "/eviltrout"

        notification = Fabricate(:notification, user: user)
        sign_in(notification.user)

        cookies["cn"] = "2828,100,#{notification.id}"

        get "/t/#{topic.id}.json"

        expect(response.status).to eq(200)
        expect(response.cookies["cn"]).to eq(nil)
        expect(response.headers["Set-Cookie"]).to match(%r{^cn=;.*path=/eviltrout})

        notification.reload
        expect(notification.read).to eq(true)
      end

      it "correctly clears notifications if specified via header" do
        notification = Fabricate(:notification, user: user)
        sign_in(notification.user)

        get "/t/#{topic.id}.json",
            headers: {
              "Discourse-Clear-Notifications" => "2828,100,#{notification.id}",
            }

        expect(response.status).to eq(200)
        notification.reload
        expect(notification.read).to eq(true)
      end
    end

    describe "read only header" do
      it "returns a readonly header if the site is read only" do
        Discourse.received_postgres_readonly!
        get "/t/#{topic.id}.json"
        expect(response.status).to eq(200)
        expect(response.headers["Discourse-Readonly"]).to eq("true")
      end
    end

    context "when the first post is hidden" do
      fab!(:hidden_topic) do
        Fabricate(:post, user: post_author1, raw: "this is the secret hidden body text").topic
      end
      fab!(:visible_reply) do
        Fabricate(
          :post,
          topic: hidden_topic,
          post_number: 2,
          user: post_author1,
          raw: "this reply is perfectly visible",
        )
      end

      let(:bot_user_agent) do
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
      end

      before do
        hidden_topic.update_excerpt(hidden_topic.first_post.excerpt_for_topic)
        hidden_topic.first_post.hide!(PostActionType.types[:off_topic])
      end

      it "does not leak the hidden first post body in the crawler meta description" do
        get hidden_topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

        expect(response.status).to eq(200)
        expect(response.body).not_to include(hidden_topic.first_post.raw)
      end

      it "does not leak the hidden first post body when a crawler requests a visible reply" do
        get "#{hidden_topic.relative_url}/2", env: { "HTTP_USER_AGENT" => bot_user_agent }

        expect(response.status).to eq(200)
        expect(response.body).not_to include(hidden_topic.first_post.raw)
        expect(response.body).to include(visible_reply.raw)
      end

      it "does not leak the hidden first post body in the regular HTML description when requesting a visible reply" do
        get "#{hidden_topic.relative_url}/2"

        expect(response.status).to eq(200)
        expect(response.body).not_to include(hidden_topic.first_post.raw)
      end

      it "includes the first post excerpt for a viewer who can see hidden posts" do
        sign_in(admin)

        get hidden_topic.relative_url

        expect(response.status).to eq(200)
        description = Nokogiri.HTML5(response.body).at_css("meta[name='description']")["content"]
        expect(description).to include(hidden_topic.first_post.raw)
      end
    end

    context "when a reply is hidden" do
      fab!(:reply_topic) do
        Fabricate(:post, user: post_author1, raw: "the first post visible body text").topic
      end
      fab!(:hidden_reply) do
        Fabricate(
          :post,
          topic: reply_topic,
          post_number: 2,
          user: post_author1,
          raw: "this is the secret hidden reply text",
        )
      end

      let(:bot_user_agent) do
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
      end

      before do
        reply_topic.update_excerpt(reply_topic.first_post.excerpt_for_topic)
        hidden_reply.hide!(PostActionType.types[:off_topic])
      end

      it "keeps the visible first post excerpt but not the hidden reply in crawler metadata" do
        get "#{reply_topic.relative_url}/2", env: { "HTTP_USER_AGENT" => bot_user_agent }

        expect(response.status).to eq(200)
        expect(response.body).not_to include(hidden_reply.raw)
        description = Nokogiri.HTML5(response.body).at_css("meta[name='description']")["content"]
        expect(description).to include(reply_topic.first_post.raw)
      end
    end

    describe "image only topic" do
      it "uses image alt tag for meta description" do
        post =
          Fabricate(
            :post,
            user: post_author1,
            raw: "![image_description|690x405](upload://sdtr5O5xaxf0iEOxICxL36YRj86.png)",
          )

        get post.topic.url

        body = response.body
        expect(body).to have_tag(
          :meta,
          with: {
            name: "description",
            content: "[image_description]",
          },
        )
      end

      it "uses image cdn url for schema markup" do
        set_cdn_url("http://cdn.localhost")
        post = Fabricate(:post_with_uploaded_image, user: post_author1)
        CookedPostProcessor.new(post).update_post_image

        get post.topic.url

        body = response.body
        expect(body).to have_tag(:link, with: { itemprop: "image", href: post.image_url })
      end
    end

    context "with multiple chunks of posts" do
      fab!(:replies) { Fabricate.times(3, :post, topic: topic, user: post_author1) }

      before { TopicView.stubs(:chunk_size).returns(2) }

      it "includes suggested topics only in the last chunk" do
        get "#{topic.relative_url}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("suggested_topics")

        get "#{topic.relative_url}/#{replies.last.post_number}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to have_key("suggested_topics")
      end

      it "includes the suggested topics' categories when category lazy-loading is enabled" do
        SiteSetting.lazy_load_categories_groups = Group::AUTO_GROUPS[:anonymous_users].to_s
        dest_topic.update!(category: category)

        get "#{topic.relative_url}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).not_to have_key("suggested_topics")
        expect(response.parsed_body["categories"].map { |entry| entry["id"] }).to contain_exactly(
          topic.category_id,
        )

        get "#{topic.relative_url}/#{replies.last.post_number}.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to have_key("suggested_topics")
        expect(response.parsed_body["categories"].map { |entry| entry["id"] }).to contain_exactly(
          topic.category_id,
          category.id,
        )
      end
    end
  end

  describe "topic access errors with detailed_404 disabled" do
    it "returns not found for inaccessible and nonexistent topics on secondary topic endpoints" do
      SiteSetting.detailed_404 = false
      sign_in(user)

      private_message = Fabricate(:private_message_topic, user: admin, recipient: moderator)
      nonexistent_topic_id = Topic.maximum(:id) + 10_000
      requests = {
        "GET /t/:topic_id/wordpress.json" => ->(topic_id) do
          get "/t/#{topic_id}/wordpress.json", params: { best: 1 }
        end,
        "GET /t/:topic_id/post_ids.json" => ->(topic_id) { get "/t/#{topic_id}/post_ids.json" },
        "GET /t/:topic_id/posts.json" => ->(topic_id) { get "/t/#{topic_id}/posts.json" },
        "PUT /t/:id/archive-message.json" => ->(topic_id) do
          put "/t/#{topic_id}/archive-message.json"
        end,
        "PUT /t/:id/move-to-inbox.json" => ->(topic_id) { put "/t/#{topic_id}/move-to-inbox.json" },
        "PUT /t/:id/publish.json" => ->(topic_id) do
          put "/t/#{topic_id}/publish.json", params: { destination_category_id: category.id }
        end,
        "PUT /t/:topic_id/slow_mode.json" => ->(topic_id) do
          put "/t/#{topic_id}/slow_mode.json", params: { seconds: "3600" }
        end,
        "POST /t/:topic_id/notifications.json" => ->(topic_id) do
          post "/t/#{topic_id}/notifications.json",
               params: {
                 notification_level: NotificationLevels.topic_levels[:watching],
               }
        end,
      }

      requests.each do |description, perform_request|
        perform_request.call(private_message.id)
        expect(response.status).to eq(404), description
        expect(response.parsed_body["error_type"]).to eq("not_found"), description

        perform_request.call(nonexistent_topic_id)
        expect(response.status).to eq(404), description
        expect(response.parsed_body["error_type"]).to eq("not_found"), description
      end
    end
  end

  describe "#post_ids" do
    fab!(:post) { Fabricate(:post, user: post_author1) }
    fab!(:topic) { post.topic }
    fab!(:post2) { Fabricate(:post, user: post_author2, topic:, percent_rank: 0.2) }
    fab!(:post3) { Fabricate(:post, user: post_author3, topic:, percent_rank: 0.5) }

    before { TopicView.stubs(:chunk_size).returns(1) }

    after { TopicView.custom_filters.clear }

    it "returns post ids after the given post and applies post filters" do
      get "/t/#{topic.id}/post_ids.json", params: { post_number: post.post_number }
      expect(response.status).to eq(200)
      expect(response.parsed_body["post_ids"]).to eq([post2.id, post3.id])

      get "/t/#{topic.id}/post_ids.json",
          params: {
            post_number: post.post_number,
            username_filters: post2.user.username,
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["post_ids"]).to eq([post2.id])

      get "/t/#{topic.id}/post_ids.json",
          params: {
            post_number: post.post_number,
            filter: "summary",
          }
      expect(response.status).to eq(200)
      expect(response.parsed_body["post_ids"]).to eq([post2.id])

      TopicView.add_custom_filter("percent") { |posts, _topic_view| posts.where(percent_rank: 0.5) }

      get "/t/#{topic.id}.json", params: { post_number: post.post_number, filter: "percent" }
      expect(response.status).to eq(200)
      expect(
        response.parsed_body["post_stream"]["posts"].map { |post_json| post_json["id"] },
      ).to eq([post3.id])
    end
  end

  describe "#posts" do
    fab!(:post) { Fabricate(:post, user: post_author1) }
    fab!(:topic) { post.topic }

    after { Discourse.redis.flushdb }

    it "returns the first post, optionally with raw and suggested topics" do
      create_post(user: user_2)

      get "/t/#{topic.id}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["post_stream"]["posts"].first["id"]).to eq(post.id)
      expect(response.parsed_body["suggested_topics"]).to eq(nil)

      get "/t/#{topic.id}/posts.json?include_suggested=true"
      expect(response.parsed_body["suggested_topics"]).not_to eq(nil)

      get "/t/#{topic.id}/posts.json?include_raw=true&post_id[]=#{post.id}"
      expect(response.status).to eq(200)
      expect(response.parsed_body["post_stream"]["posts"].first["raw"]).to eq(post.raw)
    end

    it "omits reply-to user names when names are disabled" do
      SiteSetting.enable_names = false
      post.user.update!(name: "Hidden Reply Target")
      reply =
        Fabricate(
          :post,
          topic: topic,
          user: post_author2,
          reply_to_post_number: post.post_number,
          reply_to_user_id: post.user_id,
        )

      get "/t/#{topic.id}/posts.json", params: { post_ids: [reply.id] }

      expect(response.status).to eq(200)
      posts = response.parsed_body["post_stream"]["posts"]
      reply_post = posts.find { |post_json| post_json["id"] == reply.id }
      reply_to_user = reply_post["reply_to_user"]

      expect(reply_to_user).to include("id" => post.user_id, "username" => post.user.username)
      expect(reply_to_user).not_to have_key("name")
      expect(response.body).not_to include(post.user.name)
    end

    it "applies username and summary filters" do
      post2 = Fabricate(:post, user: post_author2, topic: topic, percent_rank: 0.2)
      Fabricate(:post, user: post_author3, topic: topic)
      TopicView.stubs(:chunk_size).returns(2)

      get "/t/#{topic.id}/posts.json",
          params: {
            post_number: post.post_number,
            username_filters: post2.user.username,
            asc: true,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["post_stream"]["posts"].first["id"]).to eq(post2.id)

      get "/t/#{topic.id}/posts.json",
          params: {
            post_number: post.post_number,
            filter: "summary",
            asc: true,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["post_stream"]["posts"].first["id"]).to eq(post2.id)
    end

    describe "#posts with content localization" do
      fab!(:localized_post) do
        post = Fabricate(:post, user:, locale: "en", cooked: "<p>Original EN</p>")
        Fabricate(:post_localization, post:, locale: "ja", cooked: "<p>Translated JA</p>")
        post
      end
      fab!(:localized_topic) { localized_post.topic }
      fab!(:localized_post2) do
        post =
          Fabricate(
            :post,
            user:,
            topic: localized_topic,
            locale: "ja",
            cooked: "<p>Original 2 JA</p>",
          )
        Fabricate(:post_localization, post:, locale: "en", cooked: "<p>Translated 2 EN</p>")
        post
      end

      before do
        SiteSetting.content_localization_enabled = true
        I18n.locale = "en"
      end

      it "returns translated posts unless automatic translation is disabled by cookie" do
        get "/t/#{localized_topic.id}/posts.json"

        expect(response.status).to eq(200)
        posts = response.parsed_body["post_stream"]["posts"]
        expect(posts.first["cooked"]).to eq("<p>Original EN</p>")
        expect(posts.second["cooked"]).to eq("<p>Translated 2 EN</p>")

        get "/t/#{localized_topic.id}/posts.json", params: { post_ids: [localized_post2.id] }

        expect(response.status).to eq(200)
        posts = response.parsed_body["post_stream"]["posts"]
        expect(posts.first["cooked"]).to eq("<p>Translated 2 EN</p>")

        cookies[ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE] = "false"

        get "/t/#{localized_topic.id}/posts.json"

        expect(response.status).to eq(200)
        posts = response.parsed_body["post_stream"]["posts"]
        expect(posts.first["cooked"]).to eq("<p>Original EN</p>")
        expect(posts.second["cooked"]).to eq("<p>Original 2 JA</p>")

        get "/t/#{localized_topic.id}/posts.json", params: { post_ids: [localized_post2.id] }

        expect(response.status).to eq(200)
        posts = response.parsed_body["post_stream"]["posts"]
        expect(posts.first["cooked"]).to eq("<p>Original 2 JA</p>")
      end
    end
  end

  describe "#feed" do
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    it "renders the rss feed with crawler headers and sanitized links" do
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/rss+xml")

      # our RSS feed is full of post 1/2/3/4/5 links, we do not want it included
      # in the index, and do not want links followed
      # this allows us to remove it while allowing via robots.txt
      expect(response.headers["X-Robots-Tag"]).to eq("noindex, nofollow")

      topic.update!(title: "This is a big topic title with a ")
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("")

      set_subfolder "/forum"
      get "/t/foo/#{topic.id}.rss"
      expect(response.status).to eq(200)
      expect(response.body).to_not include("/forum/forum")
      expect(response.body).to include("http://test.localhost/forum/t/#{topic.slug}")
    end

    it "returns 404 when every post is deleted" do
      topic.posts.each(&:trash!)

      get "/t/foo/#{topic.id}.rss"

      expect(response.status).to eq(404)
    end

    it "returns 404 when the topic is deleted but its posts are live" do
      topic.trash!

      get "/t/foo/#{topic.id}.rss"

      expect(response.status).to eq(404)
    end

    context "when the first post is hidden" do
      fab!(:hidden_topic) do
        Fabricate(:post, user: post_author1, raw: "this is the secret hidden body text").topic
      end

      before { hidden_topic.first_post.hide!(PostActionType.types[:off_topic]) }

      it "does not leak the hidden first post body in the channel description" do
        get "/t/foo/#{hidden_topic.id}.rss"

        expect(response.status).to eq(200)
        expect(response.body).not_to include("this is the secret hidden body text")
      end
    end
  end

  describe "#make_banner" do
    it "needs you to be a staff member" do
      tl4_topic = Fabricate(:topic, user: sign_in(trust_level_4))
      put "/t/#{tl4_topic.id}/make-banner.json"
      expect(response).to be_forbidden
    end

    describe "when logged in" do
      it "changes the topic archetype to 'banner'" do
        admin_topic = Fabricate(:topic, user: sign_in(admin))

        put "/t/#{admin_topic.id}/make-banner.json"
        expect(response.status).to eq(200)
        admin_topic.reload
        expect(admin_topic.archetype).to eq(Archetype.banner)
      end
    end
  end

  describe "#remove_banner" do
    it "needs you to be a staff member" do
      tl4_topic = Fabricate(:topic, user: sign_in(trust_level_4), archetype: Archetype.banner)
      put "/t/#{tl4_topic.id}/remove-banner.json"
      expect(response).to be_forbidden
    end

    describe "when logged in" do
      it "resets the topic archetype" do
        admin_topic = Fabricate(:topic, user: sign_in(admin), archetype: Archetype.banner)

        put "/t/#{admin_topic.id}/remove-banner.json"
        expect(response.status).to eq(200)
        admin_topic.reload
        expect(admin_topic.archetype).to eq(Archetype.default)
      end
    end
  end

  describe "removing private message participants" do
    fab!(:creator) { Fabricate(:user, trust_level: 2) }
    fab!(:recipient, :user)
    fab!(:recipient_group, :group)
    fab!(:private_topic) do
      Fabricate(
        :private_message_topic,
        user: creator,
        topic_allowed_users: [
          Fabricate.build(:topic_allowed_user, user: creator),
          Fabricate.build(:topic_allowed_user, user: recipient),
        ],
        topic_allowed_groups: [Fabricate.build(:topic_allowed_group, group: recipient_group)],
      )
    end

    it "prevents a removed creator from removing an allowed user or group" do
      recipient_group.add(user_2)
      sign_in(admin)
      put "/t/#{private_topic.id}/remove-allowed-user.json", params: { username: creator.username }
      expect(response.status).to eq(200)
      expect(response.parsed_body["success"]).to eq("OK")
      expect(creator.guardian.can_see?(private_topic)).to eq(false)

      sign_in(creator)

      put "/t/#{private_topic.id}/remove-allowed-user.json",
          params: {
            username: recipient.username,
          }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present
      expect(private_topic.allowed_users.reload).to contain_exactly(recipient)
      expect(recipient.guardian.can_see?(private_topic)).to eq(true)

      put "/t/#{private_topic.id}/remove-allowed-group.json", params: { name: recipient_group.name }
      expect(response.status).to eq(403)
      expect(response.parsed_body["errors"]).to be_present
      expect(private_topic.allowed_groups.reload).to contain_exactly(recipient_group)
      expect(user_2.guardian.can_see?(private_topic)).to eq(true)
    end
  end

  describe "#remove_allowed_user" do
    it "admin can be removed from a pm" do
      sign_in(admin)
      pm = Fabricate(:private_message_topic, user: user, recipient: admin)

      put "/t/#{pm.id}/remove-allowed-user.json", params: { username: admin.username }

      expect(response.status).to eq(200)
      expect(TopicAllowedUser.where(topic_id: pm.id, user_id: admin.id).first).to eq(nil)
    end
  end

  describe "#bulk" do
    it "needs you to be logged in" do
      put "/topics/bulk.json"
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      fab!(:topic_2, :topic)

      before { sign_in(user) }

      let(:operation) { { type: "change_category", category_id: "1", silent: true } }
      let(:topic_ids) { [1, 2, 3] }

      it "validates the topic ids and operation params" do
        put "/topics/bulk.json", params: { operation: operation }
        expect(response.status).to eq(400)

        put "/topics/bulk.json", params: { topic_ids: topic_ids }
        expect(response.status).to eq(400)

        put "/topics/bulk.json", params: { topic_ids: topic_ids, operation: {} }
        expect(response.status).to eq(400)

        put "/topics/bulk.json",
            params: {
              topic_ids: topic_ids,
              operation: {
                type: "not_a_real_operation",
              },
            }
        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"]).to be_present
      end

      it "deletes topics for a member of delete_all_posts_and_topics_allowed_groups" do
        group = Fabricate(:group)
        group.add(user)
        SiteSetting.delete_all_posts_and_topics_allowed_groups = "1|2|#{group.id}"
        target_topic = Fabricate(:topic_with_op, user: post_author1)

        put "/topics/bulk.json",
            params: {
              topic_ids: [target_topic.id],
              operation: {
                type: "delete",
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_ids"]).to contain_exactly(target_topic.id)
        expect(target_topic.reload.trashed?).to eq(true)
      end

      it "dismisses posts in nested subcategories and tagged topics as read" do
        SiteSetting.max_category_nesting = 3
        subcategory = Fabricate(:category, parent_category_id: category.id)
        sub_subcategory = Fabricate(:category, parent_category_id: subcategory.id)
        subcategory_topic = Fabricate(:topic, category: subcategory)
        sub_subcategory_topic = Fabricate(:topic, category: sub_subcategory)

        [subcategory_topic, sub_subcategory_topic].each do |dismissed_topic|
          create_post(user: user, topic_id: dismissed_topic.id)
          create_post(user: post_author2, topic_id: dismissed_topic.id)
        end

        put "/topics/bulk.json",
            params: {
              category_id: category.id,
              include_subcategories: true,
              filter: "unread",
              operation: {
                type: "dismiss_posts",
              },
            }

        expect(response.status).to eq(200)
        expect(TopicUser.get(subcategory_topic, user).last_read_post_number).to eq(2)
        expect(TopicUser.get(sub_subcategory_topic, user).last_read_post_number).to eq(2)
      end

      it "dismisses tagged topics as read" do
        TopicTag.create!(topic_id: topic.id, tag_id: tag.id)

        post1 = create_post(user: user, topic_id: topic.id)
        create_post(user: post_author2, topic_id: topic.id)

        put "/topics/bulk.json",
            params: {
              tag_name: tag.name,
              filter: "unread",
              operation: {
                type: "dismiss_posts",
              },
            }

        expect(response.status).to eq(200)
        expect(TopicUser.get(post1.topic, post1.user).last_read_post_number).to eq(2)
      end

      it "appends tags by id and by name" do
        SiteSetting.tagging_enabled = true
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        tag_by_id = Fabricate(:tag)
        tag_by_name = Fabricate(:tag)
        topic_by_id = Fabricate(:topic_with_op, user: user)
        topic_by_name = Fabricate(:topic_with_op, user: user)

        put "/topics/bulk.json",
            params: {
              topic_ids: [topic_by_id.id],
              operation: {
                type: "append_tags",
                tag_ids: [tag_by_id.id],
              },
            }

        expect(response.status).to eq(200)
        expect(topic_by_id.reload.tags).to include(tag_by_id)

        put "/topics/bulk.json",
            params: {
              topic_ids: [topic_by_name.id],
              operation: {
                type: "append_tags",
                tags: [tag_by_name.name],
              },
            }

        expect(response.status).to eq(200)
        expect(topic_by_name.reload.tags).to include(tag_by_name)
      end

      it "manages tags with add, remove, replace and remove_all_tags" do
        SiteSetting.tagging_enabled = true
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_0]
        tag_1 = Fabricate(:tag)
        tag_2 = Fabricate(:tag)
        tag_3 = Fabricate(:tag)
        tag_4 = Fabricate(:tag)
        topics = [
          Fabricate(:topic_with_op, user: user, tags: [tag_1, tag_2]),
          Fabricate(:topic_with_op, user: user, tags: [tag_2, tag_3]),
          Fabricate(:topic_with_op, user: user, tags: [tag_1]),
        ]

        put "/topics/bulk.json",
            params: {
              topic_ids: topics.map(&:id),
              operation: {
                type: "manage_tags",
                add_tag_ids: [tag_4.id],
                remove_tag_ids: [tag_2.id],
                replace_tags: [{ from_tag_id: tag_1.id, to_tag_id: tag_3.id }],
              },
            }

        expect(response.status).to eq(200)
        topics.each do |managed_topic|
          expect(managed_topic.reload.tags).to contain_exactly(tag_3, tag_4)
        end

        put "/topics/bulk.json",
            params: {
              topic_ids: topics.map(&:id),
              operation: {
                type: "manage_tags",
                remove_all_tags: true,
              },
            }

        expect(response.status).to eq(200)
        topics.each { |managed_topic| expect(managed_topic.reload.tags).to be_empty }
      end

      it "includes errors in the response when operations partially fail" do
        sign_in(Fabricate(:moderator))

        restricted_tag = Fabricate(:tag, name: "restricted-tag")
        source_category = Fabricate(:category, tags: [restricted_tag])
        destination_category = Fabricate(:category, tags: [Fabricate(:tag, name: "other-tag")])
        topic_with_tag = Fabricate(:topic, category: source_category, tags: [restricted_tag])
        Fabricate(:post, topic: topic_with_tag)

        put "/topics/bulk.json",
            params: {
              topic_ids: [topic_with_tag.id],
              operation: {
                type: "change_category",
                category_id: destination_category.id,
              },
            }

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["topic_ids"]).to eq([])
        expect(json["errors"]).to be_present
        expect(json["errors"].values.sum).to eq(1)
      end

      context "with private message" do
        fab!(:group) do
          Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap do |g|
            g.add(user_2)
          end
        end

        fab!(:group_message) do
          create_post(
            user: user,
            target_group_names: [group.name],
            archetype: Archetype.private_message,
          ).topic.tap { |group_topic| create_post(user: user, topic: group_topic) }
        end

        fab!(:private_message) do
          create_post(
            user: user,
            target_usernames: [user_2.username],
            archetype: Archetype.private_message,
          ).topic.tap { |message_topic| create_post(user: user, topic: message_topic) }
        end

        fab!(:private_message_2) do
          create_post(
            user: user,
            target_usernames: [user_2.username],
            archetype: Archetype.private_message,
          ).topic.tap { |message_topic| create_post(user: user, topic: message_topic) }
        end

        fab!(:group_pm_topic_user) do
          TopicUser
            .find_by(user: user_2, topic: group_message)
            .tap { |topic_user| topic_user.update!(last_read_post_number: 1) }
        end

        fab!(:regular_pm_topic_user) do
          TopicUser
            .find_by(user: user_2, topic: private_message)
            .tap { |topic_user| topic_user.update!(last_read_post_number: 1) }
        end

        fab!(:regular_pm_topic_user_2) do
          TopicUser
            .find_by(user: user_2, topic: private_message_2)
            .tap { |topic_user| topic_user.update!(last_read_post_number: 1) }
        end

        before { sign_in(user_2) }

        it "can dismiss all user and group private message topics" do
          expect do
            put "/topics/bulk.json",
                params: {
                  filter: "unread",
                  operation: {
                    type: "dismiss_posts",
                  },
                  private_message_inbox: "all",
                }

            expect(response.status).to eq(200)
          end.to change { group_pm_topic_user.reload.last_read_post_number }.from(1).to(
            2,
          ).and change { regular_pm_topic_user.reload.last_read_post_number }.from(1).to(2)
        end

        it "dismisses the personal inbox across pagination without dismissing group messages" do
          stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 1) do
            put "/topics/bulk.json",
                params: {
                  filter: "unread",
                  operation: {
                    type: "dismiss_posts",
                  },
                  private_message_inbox: "user",
                }

            expect(response.status).to eq(200)
          end

          expect(regular_pm_topic_user.reload.last_read_post_number).to eq(2)
          expect(regular_pm_topic_user_2.reload.last_read_post_number).to eq(2)
          expect(group_pm_topic_user.reload.last_read_post_number).to eq(1)
        end

        it "dismisses the group inbox without dismissing personal messages" do
          put "/topics/bulk.json",
              params: {
                filter: "unread",
                operation: {
                  type: "dismiss_posts",
                },
                private_message_inbox: "group",
                group_name: group.name,
              }

          expect(response.status).to eq(200)
          expect(group_pm_topic_user.reload.last_read_post_number).to eq(2)
          expect(regular_pm_topic_user.reload.last_read_post_number).to eq(1)
          expect(regular_pm_topic_user_2.reload.last_read_post_number).to eq(1)
        end

        it "returns not found for an invalid or restricted group" do
          put "/topics/bulk.json",
              params: {
                filter: "unread",
                operation: {
                  type: "dismiss_posts",
                },
                private_message_inbox: "group",
                group_name: "randomgroup",
              }
          expect(response.status).to eq(404)

          sign_in(user)

          put "/topics/bulk.json",
              params: {
                filter: "unread",
                operation: {
                  type: "dismiss_posts",
                },
                private_message_inbox: "group",
                group_name: group.name,
              }
          expect(response.status).to eq(404)
        end
      end

      it "can find unread" do
        # mark all unread muted
        put "/topics/bulk.json",
            params: {
              filter: "unread",
              operation: {
                type: :change_notification_level,
                notification_level_id: 0,
              },
            }

        expect(response.status).to eq(200)
      end

      it "delegates work to `TopicsBulkAction`" do
        topics_bulk_action = mock
        TopicsBulkAction
          .expects(:new)
          .with(user, topic_ids, operation, group: nil)
          .returns(topics_bulk_action)
        topics_bulk_action.expects(:perform!)

        put "/topics/bulk.json", params: { topic_ids: topic_ids, operation: operation }
      end

      it "validates explicit topic ids before processing them" do
        put "/topics/bulk.json", params: { topic_ids: "1", operation: operation }
        expect(response.parsed_body["errors"].first).to match(
          /Expecting topic_ids to contain a list/,
        )

        put "/topics/bulk.json", params: { topic_ids: [1], operation: operation }
        expect(response.parsed_body["errors"]).to eq(nil)

        sign_in(trust_level_0)

        put "/topics/bulk.json",
            params: {
              topic_ids: Array.new(5, 0),
              operation: {
                type: "dismiss_posts",
              },
            },
            as: :json

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_ids"].size).to eq(1)
        expect(response.parsed_body["topic_ids"].first).to eq(0)

        put "/topics/bulk.json",
            params: {
              topic_ids: (1..1_001).to_a,
              operation: {
                type: "dismiss_posts",
              },
            },
            as: :json

        expect(response.status).to eq(400)
        expect(response.parsed_body["errors"].first).to include(
          I18n.t("topics_bulk_action.too_many_topic_ids", limit: 1_000),
        )
      end

      it "can pin multiple topics with pinned_until and unpin them" do
        sign_in(moderator)
        pinned_until = 3.days.from_now.beginning_of_minute.iso8601

        put "/topics/bulk.json",
            params: {
              topic_ids: [topic.id, topic_2.id],
              operation: {
                type: "pin",
                pinned_globally: false,
                pinned_until: pinned_until,
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_ids"]).to contain_exactly(topic.id, topic_2.id)
        expect(topic.reload.pinned_until).to be_within_one_second_of(Time.parse(pinned_until))
        expect(topic_2.reload.pinned_until).to be_within_one_second_of(Time.parse(pinned_until))

        put "/topics/bulk.json",
            params: {
              topic_ids: [topic.id, topic_2.id],
              operation: {
                type: "unpin",
              },
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_ids"]).to contain_exactly(topic.id, topic_2.id)
      end

      it "respects the tracked parameter" do
        # untracked topic
        CategoryUser.set_notification_level_for_category(
          user,
          NotificationLevels.all[:regular],
          category.id,
        )
        create_post(user: user, topic_id: topic.id)
        topic.update!(category_id: category.id)
        create_post(user: post_author2, topic_id: topic.id)

        # tracked topic
        CategoryUser.set_notification_level_for_category(
          user,
          NotificationLevels.all[:tracking],
          tracked_category.id,
        )
        tracked_topic = create_post(user: user).topic
        tracked_topic.update!(category_id: tracked_category.id)
        create_post(user: post_author2, topic_id: tracked_topic.id)

        put "/topics/bulk.json",
            params: {
              filter: "unread",
              operation: {
                type: "dismiss_posts",
              },
              tracked: true,
            }

        expect(response.status).to eq(200)
        expect(TopicUser.get(topic, user).last_read_post_number).to eq(topic.posts.count - 1)
        expect(TopicUser.get(tracked_topic, user).last_read_post_number).to eq(
          tracked_topic.posts.count,
        )
      end
    end
  end

  describe "#remove_bookmarks" do
    it "requires login and returns not found for inaccessible topics" do
      put "/t/1/remove_bookmarks.json"
      expect(response.status).to eq(403)

      sign_in(user_2)
      private_message = Fabricate(:private_message_topic, user: user, recipient: post_author1)
      missing_topic_id = Topic.maximum(:id) + 1

      put "/t/#{private_message.id}/remove_bookmarks.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")

      put "/t/#{missing_topic_id}/remove_bookmarks.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
    end

    it "removes bookmarks with reminders from non-first posts" do
      sign_in(user)
      topic = Fabricate(:topic_with_op, user: user)
      reply = Fabricate(:post, topic: topic, user: user)
      Fabricate(:bookmark, user: user, bookmarkable: topic.first_post)
      Fabricate(:bookmark, user: user, bookmarkable: reply)

      put "/t/#{topic.id}/remove_bookmarks.json"

      expect(Bookmark.where(user: user).count).to eq(0)
      expect(Bookmark.for_user_in_topic(user.id, topic.id).count).to eq(0)
    end
  end

  describe "#bookmark" do
    it "returns not found for inaccessible private messages" do
      sign_in(user_2)
      private_message = Fabricate(:private_message_topic, user: user, recipient: post_author1)
      missing_topic_id = Topic.maximum(:id) + 1

      put "/t/#{private_message.id}/bookmark.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")

      put "/t/#{missing_topic_id}/bookmark.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
    end

    it "creates a topic bookmark and rejects duplicates" do
      sign_in(user)
      topic = Fabricate(:topic_with_op, user: user)

      put "/t/#{topic.id}/bookmark.json"

      expect(Bookmark.find_by(user_id: user.id).bookmarkable_id).to eq(topic.id)

      put "/t/#{topic.id}/bookmark.json"
      expect(response.status).to eq(400)
    end
  end

  describe "#reset_new" do
    def dismissed_topic_ids(messages)
      message =
        messages.find do |published|
          published.data["message_type"] == TopicTrackingState::DISMISS_NEW_MESSAGE_TYPE
        end
      message&.data&.dig("payload", "topic_ids")
    end

    context "when a user is not signed in" do
      it "requires authentication" do
        put "/topics/reset-new.json"
        expect(response.status).to eq(403)
      end
    end

    context "when a user is signed in" do
      before do
        user.user_stat.update_column(:new_since, 2.years.ago)
        CategoryUser.set_notification_level_for_category(
          user,
          NotificationLevels.all[:tracking],
          tracked_category.id,
        )
        sign_in(user)
      end

      let(:old_date) { 2.years.ago }

      it "only changes `new_since` when tracked is not requested" do
        messages =
          MessageBus.track_publish(TopicTrackingState.unread_channel_key(user.id)) do
            put "/topics/reset-new.json?tracked=true"
            expect(response.status).to eq(200)
          end

        expect(dismissed_topic_ids(messages)).to be_nil
        expect(user.reload.user_stat.new_since.to_date).to eq(old_date.to_date)
        expect(DismissedTopicUser.where(user: user)).to be_empty

        messages =
          MessageBus.track_publish(TopicTrackingState.unread_channel_key(user.id)) do
            put "/topics/reset-new.json"
            expect(response.status).to eq(200)
          end

        expect(dismissed_topic_ids(messages)).to be_nil
        expect(user.reload.user_stat.new_since.to_date).not_to eq(old_date.to_date)
      end

      it "creates dismissed topic records only for tracked new topics" do
        tracked_topic = create_post(category: tracked_category, user: post_author1).topic
        create_post(user: post_author1)

        expect do
          put "/topics/reset-new.json?tracked=true", params: { dismiss_topics: true }
        end.to change {
          DismissedTopicUser.where(user_id: user.id, topic_id: tracked_topic.id).count
        }.by(1)
        expect(DismissedTopicUser.where(user: user).count).to eq(1)
      end

      it "dismisses tracked new topics across pagination, explicit ids and tracked=false" do
        tracked_topics =
          Array.new(5) { create_post(category: tracked_category, user: post_author1).topic }
        extra_topics = [
          create_post(user: post_author1).topic,
          create_post(user: post_author1).topic,
        ]
        tracked_topic_ids = tracked_topics.map(&:id)
        all_topic_ids = tracked_topic_ids + extra_topics.map(&:id)

        stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 2) do
          put "/topics/reset-new.json?tracked=true",
              params: {
                dismiss_topics: true,
                topic_ids: tracked_topic_ids.first(4),
              }
        end
        expect(DismissedTopicUser.where(user: user, topic_id: tracked_topic_ids).count).to eq(4)
        DismissedTopicUser.where(user: user).delete_all

        stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 2) do
          put "/topics/reset-new.json?tracked=true", params: { dismiss_topics: true }
        end
        expect(DismissedTopicUser.where(user: user, topic_id: tracked_topic_ids).count).to eq(5)
        DismissedTopicUser.where(user: user).delete_all

        DismissedTopicUser.create!(user_id: user.id, topic_id: all_topic_ids[0])
        DismissedTopicUser.create!(user_id: user.id, topic_id: all_topic_ids[1])
        old_new_since = user.user_stat.new_since

        expect do
          put "/topics/reset-new.json?tracked=false", params: { dismiss_topics: true }
        end.to change {
          DismissedTopicUser.where(user_id: user.id, topic_id: all_topic_ids).count
        }.by(5)

        expect(DismissedTopicUser.where(user: user, topic_id: all_topic_ids).count).to eq(7)
        expect(user.reload.user_stat.new_since > old_new_since).to eq(true)
      end

      it "dismisses new topics for a category and its descendants" do
        SiteSetting.max_category_nesting = 3
        subcategory = Fabricate(:category, parent_category_id: category.id)
        sub_subcategory = Fabricate(:category, parent_category_id: subcategory.id)
        category_topic = Fabricate(:topic, category: category)
        subcategory_topic = Fabricate(:topic, category: subcategory)
        sub_subcategory_topic = Fabricate(:topic, category: sub_subcategory)
        channel = TopicTrackingState.unread_channel_key(user.id)

        messages =
          MessageBus.track_publish(channel) do
            put "/topics/reset-new.json", params: { dismiss_topics: true, category_id: category.id }
            expect(response.status).to eq(200)
          end
        expect(dismissed_topic_ids(messages)).to eq([category_topic.id])
        expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to eq([category_topic.id])

        DismissedTopicUser.where(user: user).delete_all
        SiteSetting.max_category_nesting = 2

        messages =
          MessageBus.track_publish(channel) do
            put "/topics/reset-new.json",
                params: {
                  dismiss_topics: true,
                  category_id: category.id,
                  include_subcategories: true,
                }
            expect(response.status).to eq(200)
          end
        expect(dismissed_topic_ids(messages)).to contain_exactly(
          category_topic.id,
          subcategory_topic.id,
        )
        expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to contain_exactly(
          category_topic.id,
          subcategory_topic.id,
        )

        DismissedTopicUser.where(user: user).delete_all
        SiteSetting.max_category_nesting = 3

        messages =
          MessageBus.track_publish(channel) do
            put "/topics/reset-new.json",
                params: {
                  dismiss_topics: true,
                  category_id: category.id,
                  include_subcategories: true,
                }
            expect(response.status).to eq(200)
          end
        expect(dismissed_topic_ids(messages)).to contain_exactly(
          category_topic.id,
          subcategory_topic.id,
          sub_subcategory_topic.id,
        )
        expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to contain_exactly(
          category_topic.id,
          subcategory_topic.id,
          sub_subcategory_topic.id,
        )
      end

      context "when the category has private child categories" do
        fab!(:category)
        fab!(:group)
        fab!(:private_child_category) do
          Fabricate(:private_category, parent_category: category, group: group)
        end
        fab!(:public_child_category) { Fabricate(:category, parent_category: category) }
        fab!(:topic_in_private_child_category) do
          Fabricate(:topic, category: private_child_category)
        end
        fab!(:topic_in_public_child_category) { Fabricate(:topic, category: public_child_category) }

        it "only dismisses topics in private child categories the user can see" do
          channel = TopicTrackingState.unread_channel_key(user.id)

          messages =
            MessageBus.track_publish(channel) do
              put "/topics/reset-new.json",
                  params: {
                    dismiss_topics: true,
                    category_id: category.id,
                    include_subcategories: true,
                  }
              expect(response.status).to eq(200)
            end
          expect(messages.size).to eq(1)
          expect(messages[0].user_ids).to eq([user.id])
          expect(dismissed_topic_ids(messages)).to eq([topic_in_public_child_category.id])
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to eq(
            [topic_in_public_child_category.id],
          )

          group.add(user)
          DismissedTopicUser.where(user: user).delete_all

          messages =
            MessageBus.track_publish(channel) do
              put "/topics/reset-new.json",
                  params: {
                    dismiss_topics: true,
                    category_id: category.id,
                    include_subcategories: true,
                  }
              expect(response.status).to eq(200)
            end
          expect(messages.size).to eq(1)
          expect(messages[0].user_ids).to eq([user.id])
          expect(dismissed_topic_ids(messages)).to contain_exactly(
            topic_in_public_child_category.id,
            topic_in_private_child_category.id,
          )
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to contain_exactly(
            topic_in_public_child_category.id,
            topic_in_private_child_category.id,
          )
        end
      end

      context "when the category is private" do
        fab!(:group)
        fab!(:private_category) { Fabricate(:private_category, group: group) }
        fab!(:topic_in_private_category) { Fabricate(:topic, category: private_category) }

        it "dismisses and publishes only when the user can access the category" do
          messages =
            MessageBus.track_publish do
              put "/topics/reset-new.json",
                  params: {
                    dismiss_topics: true,
                    category_id: private_category.id,
                  }
              expect(response.status).to eq(200)
            end
          expect(messages.size).to eq(0)
          expect(DismissedTopicUser.where(user: user).count).to eq(0)

          group.add(user)

          messages =
            MessageBus.track_publish do
              put "/topics/reset-new.json",
                  params: {
                    dismiss_topics: true,
                    category_id: private_category.id,
                  }
            end
          expect(response.status).to eq(200)
          expect(messages.size).to eq(1)
          expect(messages[0].channel).to eq(TopicTrackingState.unread_channel_key(user.id))
          expect(messages[0].user_ids).to eq([user.id])
          expect(dismissed_topic_ids(messages)).to eq([topic_in_private_category.id])
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to eq(
            [topic_in_private_category.id],
          )
        end
      end

      context "with tag" do
        fab!(:tag_topic, :topic)
        fab!(:topic_tag) { Fabricate(:topic_tag, topic: tag_topic, tag: tag) }

        it "dismisses topics for tag" do
          messages =
            MessageBus.track_publish(TopicTrackingState.unread_channel_key(user.id)) do
              put "/topics/reset-new.json?tag_name=#{tag.name}", params: { dismiss_topics: true }
              expect(response.status).to eq(200)
            end
          expect(dismissed_topic_ids(messages)).to eq([tag_topic.id])
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to eq([tag_topic.id])
        end

        context "when the tag is restricted" do
          fab!(:restricted_tag) { Fabricate(:tag, name: "restricted-tag") }
          fab!(:topic_with_restricted_tag) { Fabricate(:topic, tags: [restricted_tag]) }
          fab!(:group)
          fab!(:topic_without_tag, :topic)
          fab!(:tag_group) do
            Fabricate(
              :tag_group,
              name: "Restricted Tag Group",
              tag_names: ["restricted-tag"],
              permissions: [[group, TagGroupPermission.permission_types[:full]]],
            )
          end

          it "respects the tag param only when the user can see the tag" do
            messages =
              MessageBus.track_publish do
                put "/topics/reset-new.json",
                    params: {
                      dismiss_topics: true,
                      tag_name: restricted_tag.name,
                    }
              end
            expect(messages.size).to eq(1)
            expect(dismissed_topic_ids(messages)).to contain_exactly(
              topic_with_restricted_tag.id,
              tag_topic.id,
              topic_without_tag.id,
            )
            expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to contain_exactly(
              topic_with_restricted_tag.id,
              tag_topic.id,
              topic_without_tag.id,
            )

            group.add(user)
            DismissedTopicUser.where(user: user).delete_all

            messages =
              MessageBus.track_publish do
                put "/topics/reset-new.json",
                    params: {
                      dismiss_topics: true,
                      tag_name: restricted_tag.name,
                    }
              end
            expect(messages.size).to eq(1)
            expect(dismissed_topic_ids(messages)).to contain_exactly(topic_with_restricted_tag.id)
            expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to contain_exactly(
              topic_with_restricted_tag.id,
            )
          end
        end
      end

      context "with tag and category" do
        fab!(:tag_topic, :topic)
        fab!(:topic_tag) { Fabricate(:topic_tag, topic: tag_topic, tag: tag) }
        fab!(:tag_and_category_topic) { Fabricate(:topic, category: category) }
        fab!(:topic_tag2) { Fabricate(:topic_tag, topic: tag_and_category_topic, tag: tag) }

        it "dismisses topics matching both tag and category" do
          messages =
            MessageBus.track_publish(TopicTrackingState.unread_channel_key(user.id)) do
              put "/topics/reset-new.json?tag_name=#{tag.name}&category_id=#{category.id}",
                  params: {
                    dismiss_topics: true,
                  }
            end
          expect(dismissed_topic_ids(messages)).to eq([tag_and_category_topic.id])
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to eq(
            [tag_and_category_topic.id],
          )
        end
      end

      context "with specific topics" do
        fab!(:topic2, :topic)
        fab!(:topic3, :topic)

        it "dismisses explicit topics and validates the topic_ids param" do
          put "/topics/reset-new.json", params: { topic_ids: topic2.id }
          expect(response.parsed_body["errors"].first).to match(
            /Expecting topic_ids to contain a list/,
          )

          messages =
            MessageBus.track_publish(TopicTrackingState.unread_channel_key(user.id)) do
              put "/topics/reset-new.json",
                  params: {
                    dismiss_topics: true,
                    topic_ids: [topic2.id, topic3.id],
                  }
              expect(response.status).to eq(200)
            end

          expect(user.reload.user_stat.new_since.to_date).not_to eq(old_date.to_date)
          expect(dismissed_topic_ids(messages)).to match_array([topic2.id, topic3.id])
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to match_array(
            [topic2.id, topic3.id],
          )
        end

        it "doesn't dismiss topics that the user can't see" do
          private_category = Fabricate(:private_category, group: Fabricate(:group))
          topic2.update!(category_id: private_category.id)

          messages =
            MessageBus.track_publish do
              put "/topics/reset-new.json",
                  params: {
                    dismiss_topics: true,
                    topic_ids: [topic2.id, topic3.id],
                  }
            end
          expect(messages.size).to eq(1)
          expect(messages[0].channel).to eq(TopicTrackingState.unread_channel_key(user.id))
          expect(messages[0].user_ids).to eq([user.id])
          expect(dismissed_topic_ids(messages)).to eq([topic3.id])
          expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to eq([topic3.id])
        end

        describe "when tracked param is true" do
          it "does not update new_since and dismisses only tracked topics" do
            put "/topics/reset-new.json?tracked=true", params: { topic_ids: [topic2.id, topic3.id] }
            expect(response.status).to eq(200)
            expect(user.reload.user_stat.new_since.to_date).to eq(old_date.to_date)
            expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to be_empty

            tracked_topic = create_post(category: tracked_category, user: post_author1).topic
            topic2.update!(category_id: tracked_category.id)

            put "/topics/reset-new.json?tracked=true",
                params: {
                  dismiss_topics: true,
                  topic_ids: [tracked_topic.id, topic2.id, topic3.id],
                }
            expect(response.status).to eq(200)
            expect(DismissedTopicUser.where(user: user).pluck(:topic_id)).to match_array(
              [tracked_topic.id, topic2.id],
            )
          end
        end
      end

      describe "new and unread" do
        fab!(:new_topic, :topic)
        fab!(:unread_topic) { Fabricate(:topic, highest_post_number: 3) }
        fab!(:unread_posts) do
          [
            create_post(topic: unread_topic, user: post_author1),
            create_post(topic: unread_topic, user: post_author2),
          ]
        end
        fab!(:topic_user) do
          Fabricate(
            :topic_user,
            topic: unread_topic,
            user: user,
            notification_level: NotificationLevels.topic_levels[:tracking],
            last_read_post_number: 1,
          )
        end

        before { SiteSetting.enable_unified_new = true }

        it "dismisses new topics" do
          put "/topics/reset-new.json"
          topics = TopicQuery.new(user).new_and_unread_results(limit: false)
          expect(topics).to eq([unread_topic, new_topic])
          expect(response.status).to eq(200)
          expect(response.parsed_body["topic_ids"]).to eq([])

          put "/topics/reset-new.json", params: { dismiss_topics: true }
          expect(response.status).to eq(200)
          expect(response.parsed_body["topic_ids"]).to eq([new_topic.id])

          topics = TopicQuery.new(user).new_and_unread_results(limit: false)
          expect(topics).to eq([unread_topic])
          expect(DismissedTopicUser.where(user: user).count).to eq(1)
          expect(DismissedTopicUser.where(user: user).first.topic_id).to eq(new_topic.id)
          expect(topic_user.reload.notification_level).to eq(
            NotificationLevels.topic_levels[:tracking],
          )
        end

        it "dismisses unread topics" do
          put "/topics/reset-new.json"
          expect(response.status).to eq(200)
          expect(response.parsed_body["topic_ids"]).to eq([])
          topics = TopicQuery.new(user).new_and_unread_results(limit: false)
          expect(topics).to eq([unread_topic, new_topic])

          put "/topics/reset-new.json", params: { dismiss_posts: true }
          expect(response.status).to eq(200)
          expect(response.parsed_body["topic_ids"]).to eq([unread_topic.id])

          topics = TopicQuery.new(user).new_and_unread_results(limit: false)
          expect(topics).to eq([new_topic])
          expect(DismissedTopicUser.count).to eq(0)
          expect(topic_user.reload.notification_level).to eq(
            NotificationLevels.topic_levels[:tracking],
          )
        end

        it "untrack topics" do
          expect(topic_user.notification_level).to eq(NotificationLevels.topic_levels[:tracking])
          put "/topics/reset-new.json", params: { dismiss_posts: true, untrack: true }
          expect(response.status).to eq(200)
          expect(response.parsed_body["topic_ids"]).to eq([unread_topic.id])

          expect(topic_user.reload.notification_level).to eq(
            NotificationLevels.topic_levels[:regular],
          )
        end

        it "dismisses new topics, unread posts and untrack" do
          put "/topics/reset-new.json",
              params: {
                dismiss_topics: true,
                dismiss_posts: true,
                untrack: true,
              }
          expect(response.status).to eq(200)
          expect(response.parsed_body["topic_ids"]).to eq([new_topic.id, unread_topic.id])

          topics = TopicQuery.new(user).new_and_unread_results(limit: false)
          expect(topics).to be_empty
          expect(DismissedTopicUser.where(user: user).count).to eq(1)
          expect(DismissedTopicUser.where(user: user).first.topic_id).to eq(new_topic.id)

          expect(user.topic_users.map(&:notification_level).uniq).to eq(
            [NotificationLevels.topic_levels[:regular]],
          )
        end

        context "when category" do
          fab!(:new_topic_2) { Fabricate(:topic, category: category) }
          fab!(:unread_topic_2) { Fabricate(:topic, category: category, highest_post_number: 3) }
          fab!(:topic_user) do
            Fabricate(
              :topic_user,
              topic: unread_topic_2,
              user: user,
              notification_level: NotificationLevels.topic_levels[:tracking],
              last_read_post_number: 1,
            )
          end

          it "dismisses new topics, unread posts and untrack for specific category" do
            topics = TopicQuery.new(user).new_and_unread_results(limit: false)
            expect(topics).to match_array([new_topic, new_topic_2, unread_topic, unread_topic_2])

            put "/topics/reset-new.json",
                params: {
                  dismiss_topics: true,
                  dismiss_posts: true,
                  untrack: true,
                  category_id: category.id,
                }
            expect(response.status).to eq(200)
            expect(response.parsed_body["topic_ids"]).to eq([new_topic_2.id, unread_topic_2.id])

            topics = TopicQuery.new(user).new_and_unread_results(limit: false)
            expect(topics).to match_array([new_topic, unread_topic])
          end
        end

        context "when tag" do
          fab!(:new_topic_2, :topic)
          fab!(:unread_topic_2) { Fabricate(:topic, highest_post_number: 3) }
          fab!(:topic_user) do
            Fabricate(
              :topic_user,
              topic: unread_topic_2,
              user: user,
              notification_level: NotificationLevels.topic_levels[:tracking],
              last_read_post_number: 1,
            )
          end
          fab!(:topic_tag) { Fabricate(:topic_tag, topic: new_topic_2, tag: tag) }
          fab!(:topic_tag_2) { Fabricate(:topic_tag, topic: unread_topic_2, tag: tag) }

          it "dismisses new topics, unread posts and untrack for specific tag" do
            topics = TopicQuery.new(user).new_and_unread_results(limit: false)
            expect(topics).to match_array([new_topic, new_topic_2, unread_topic, unread_topic_2])

            put "/topics/reset-new.json",
                params: {
                  dismiss_topics: true,
                  dismiss_posts: true,
                  untrack: true,
                  tag_name: tag.name,
                }

            expect(response.status).to eq(200)
            expect(response.parsed_body["topic_ids"]).to eq([new_topic_2.id, unread_topic_2.id])

            topics = TopicQuery.new(user).new_and_unread_results(limit: false)
            expect(topics).to match_array([new_topic, unread_topic])
          end
        end
      end
    end
  end

  describe "#feature_stats" do
    fab!(:category_for_stats, :category)
    fab!(:pinned_in_category_topic) do
      Fabricate(:topic, category: category_for_stats, pinned_at: 1.hour.ago, pinned_globally: false)
    end
    fab!(:globally_pinned_topic) { Fabricate(:topic, pinned_at: 1.hour.ago, pinned_globally: true) }
    fab!(:banner_topic) { Fabricate(:topic, archetype: Archetype.banner) }

    it "returns visible pin and banner counts with and without a category" do
      get "/topics/feature_stats.json", params: { category_id: category_for_stats.id }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["pinned_in_category_count"]).to eq(1)
      expect(json["pinned_globally_count"]).to eq(1)
      expect(json["banner_count"]).to eq(1)

      get "/topics/feature_stats.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).not_to have_key("pinned_in_category_count")
      expect(json["pinned_globally_count"]).to eq(1)
      expect(json["banner_count"]).to eq(1)

      banner_topic.update!(visible: false)
      get "/topics/feature_stats.json", params: { category_id: category_for_stats.id }
      expect(response.parsed_body["banner_count"]).to eq(1)

      restricted_category = Fabricate(:category, read_restricted: true)
      Fabricate(
        :topic,
        category: restricted_category,
        pinned_at: 1.hour.ago,
        pinned_globally: false,
      )
      Fabricate(:topic, category: restricted_category, pinned_at: 1.hour.ago, pinned_globally: true)
      Fabricate(:topic, category: restricted_category, archetype: Archetype.banner)

      get "/topics/feature_stats.json", params: { category_id: restricted_category.id }
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["pinned_in_category_count"]).to eq(0)
      expect(json["pinned_globally_count"]).to eq(1)
      expect(json["banner_count"]).to eq(1)
    end
  end

  describe "#excerpts" do
    it "returns excerpts for visible posts only" do
      first_post =
        create_post(raw: "This is the first post :)", title: "This is a test title I am making yay")
      second_post = create_post(raw: "This is second post", topic: first_post.topic)
      third_post = first_post.topic.add_small_action(first_post.user, "autobumped")
      random_post = Fabricate(:post, user: post_author1)

      get "/t/#{first_post.topic_id}/excerpts.json",
          params: {
            post_ids: [first_post.id, second_post.id, third_post.id, random_post.id],
          }

      expect(response.status).to eq(200)
      json = response.parsed_body
      json.sort! { |a, b| a["post_id"] <=> b["post_id"] }

      # no random post
      expect(json.map { |post| post["post_id"] }).to contain_exactly(
        first_post.id,
        second_post.id,
        third_post.id,
      )
      # keep emoji images
      expect(json[0]["excerpt"]).to match(/emoji/)
      expect(json[0]["excerpt"]).to match(/first post/)
      expect(json[0]["username"]).to eq(first_post.user.username)
      expect(json[0]["created_at"].present?).to eq(false)
      expect(json[1]["excerpt"]).to match(/second post/)
      expect(json[2]["action_code"]).to eq("autobumped")
      expect(json[2]["created_at"].present?).to eq(true)

      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
      first_post = create_post(raw: "This is the first post")
      whisper_post =
        create_post(
          raw: "This is a secret whisper",
          topic: first_post.topic,
          post_type: Post.types[:whisper],
        )

      sign_in(user)

      get "/t/#{first_post.topic_id}/excerpts.json",
          params: {
            post_ids: [first_post.id, whisper_post.id],
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.map { |post| post["post_id"] }).to contain_exactly(first_post.id)
    end
  end

  describe "#convert_topic" do
    it "needs you to be logged in" do
      put "/t/111/convert-topic/private.json"
      expect(response.status).to eq(403)
    end

    describe "converting public topic to private message" do
      fab!(:topic) { Fabricate(:topic, user: user) }
      fab!(:post) { Fabricate(:post, user: user, topic: topic) }

      it "enforces permission and the PM recipient cap" do
        sign_in(user)
        put "/t/#{topic.id}/convert-topic/private.json"
        expect(response).to be_forbidden

        SiteSetting.max_allowed_message_recipients = 2
        Fabricate(:post, topic: topic, user: post_author1, post_number: 2)
        Fabricate(:post, topic: topic, user: post_author2, post_number: 3)

        sign_in(admin)
        put "/t/#{topic.id}/convert-topic/private.json"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t(
            "topic_converter.too_many_recipients",
            max: SiteSetting.max_allowed_message_recipients,
          ),
        )
        expect(topic.reload.archetype).to eq(Archetype.default)
      end

      it "revokes a public published page when converting the topic" do
        SiteSetting.enable_page_publishing = true
        published_page = Fabricate(:published_page, topic: topic, public: true)

        get published_page.path
        expect(response.status).to eq(200)
        expect(response.body).to include(post.raw)

        sign_in(admin)
        put "/t/#{topic.id}/convert-topic/private.json"

        topic.reload
        expect(topic.archetype).to eq(Archetype.private_message)
        expect(response.status).to eq(200)

        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present

        sign_out
        get published_page.path
        expect(response.status).to eq(404)
        expect(response.body).not_to include(post.raw)
        expect(PublishedPage.exists?(topic: topic)).to eq(false)
      end
    end

    describe "converting private message to public topic" do
      fab!(:topic) { Fabricate(:private_message_topic, user: user, recipient: post_author1) }
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "requires permission and a visible destination category" do
        sign_in(user)
        put "/t/#{topic.id}/convert-topic/public.json"
        expect(response).to be_forbidden

        sign_in(moderator)
        put "/t/#{topic.id}/convert-topic/public.json"
        expect(response).to be_forbidden

        own_message = Fabricate(:private_message_topic, user: moderator, recipient: post_author1)
        Fabricate(:post, user: moderator, topic: own_message)
        private_category = Fabricate(:private_category, group: Fabricate(:group))

        put "/t/#{own_message.id}/convert-topic/public.json?category_id=#{private_category.id}"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"].first).to eq(
          I18n.t("category.errors.move_topic_to_category_disallowed"),
        )
        own_message.reload
        expect(own_message.archetype).to eq(Archetype.private_message)
        expect(own_message.category_id).to be_nil
      end

      it "publishes to a category and reports title conflicts" do
        sign_in(admin)

        put "/t/#{topic.id}/convert-topic/public.json?category_id=#{category.id}"

        topic.reload
        expect(topic.archetype).to eq(Archetype.default)
        expect(topic.category_id).to eq(category.id)
        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present

        existing_topic = Fabricate(:topic, title: "A conflicting title", category: category)
        conflicting_pm =
          Fabricate(
            :private_message_topic,
            user: user,
            recipient: post_author1,
            title: existing_topic.title,
          )
        Fabricate(:post, user: user, topic: conflicting_pm)

        put "/t/#{conflicting_pm.id}/convert-topic/public.json?category_id=#{category.id}"

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"][0]).to end_with(
          I18n.t("errors.messages.topic_title_already_used", url: existing_topic.url),
        )
      end
    end

    describe "converting a system message PM" do
      fab!(:victim, :user)
      fab!(:system_pm) { Fabricate(:system_message_topic, user: victim, recipient: post_author1) }
      fab!(:secret_post) do
        Fabricate(
          :post,
          topic: system_pm,
          user: Discourse.system_user,
          raw: "Your data export is ready: upload://topsecretexport.zip",
        )
      end

      it "allows a participant moderator to convert it to a public topic" do
        system_pm.topic_allowed_users.create!(user: moderator)
        sign_in(moderator)

        put "/t/#{system_pm.id}/convert-topic/public.json", params: { category_id: category.id }

        expect(response.status).to eq(200)
        expect(system_pm.reload.archetype).to eq(Archetype.default)
        expect(system_pm.category_id).to eq(category.id)
      end

      it "does not let a non-participant moderator publish and leak it" do
        sign_in(moderator)

        get "/t/#{system_pm.id}.json"
        expect(response.status).to eq(404)

        put "/t/#{system_pm.id}/convert-topic/public.json?category_id=#{category.id}"
        expect(response).to be_forbidden
        expect(system_pm.reload.archetype).to eq(Archetype.private_message)

        sign_out
        get "/t/#{system_pm.id}.json"
        expect(response.status).to eq(404)
        expect(response.body).not_to include("topsecretexport.zip")
      end
    end
  end

  describe "#timings" do
    fab!(:post_1) { Fabricate(:post, user: post_author1, topic: topic) }

    before do
      # admins
      SiteSetting.whispers_allowed_groups = "1"
    end

    let(:whisper) do
      Fabricate(:post, user: post_author1, topic: topic, post_type: Post.types[:whisper])
    end

    it "ignores invalid timing values for users and staff" do
      sign_in(user)
      params = {
        topic_id: topic.id,
        topic_time: 5,
        timings: {
          post_1.post_number => 2,
          whisper.post_number => 2,
          1000 => 100,
        },
      }

      post "/topics/timings.json", params: params
      expect(response.status).to eq(200)

      topic_user = TopicUser.find_by(user: user, topic: topic)
      expect(topic_user.last_read_post_number).to eq(post_1.post_number)

      # lets also test timing recovery here
      topic_user.update!(last_read_post_number: 999)

      post "/topics/timings.json", params: params

      topic_user = TopicUser.find_by(user: user, topic: topic)
      expect(topic_user.last_read_post_number).to eq(post_1.post_number)

      sign_in(admin)
      post "/topics/timings.json", params: params

      expect(response.status).to eq(200)
      expect(TopicUser.find_by(user: admin, topic: topic).last_read_post_number).to eq(
        whisper.post_number,
      )
    end

    it "does not record timings for a topic the user cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category, user: post_author1)
      private_post = Fabricate(:post, topic: private_topic, user: post_author1)

      sign_in(user)
      post "/t/#{private_post.topic_id}/timings.json",
           params: {
             topic_time: 5,
             timings: {
               private_post.post_number => 2,
             },
           }

      aggregate_failures do
        expect(response.status).to eq(404)
        expect(response.parsed_body["error_type"]).to eq("not_found")
        expect(PostTiming.where(topic: private_post.topic, user: user)).to be_empty
        expect(user.user_stat.reload.posts_read_count).to eq(0)
      end
    end

    it "records topic timings and caps read time at the max integer value" do
      sign_in(user)

      post "/topics/timings.json",
           params: {
             topic_id: topic.id,
             topic_time: 5,
             timings: {
               post_1.post_number => 2,
             },
           }

      expect(response.status).to eq(200)

      post_timing = PostTiming.take
      expect(post_timing.topic).to eq(topic)
      expect(post_timing.user).to eq(user)
      expect(post_timing.msecs).to eq(2)

      PostTiming.where(topic: topic, user: user, post_number: post_1.post_number).update_all(
        msecs: 2**31 - 10,
      )

      post "/topics/timings.json",
           params: {
             topic_id: topic.id,
             topic_time: 5,
             timings: {
               post_1.post_number => 100,
             },
           }

      expect(response.status).to eq(200)
      post_timing = PostTiming.take
      expect(post_timing.topic).to eq(topic)
      expect(post_timing.user).to eq(user)
      expect(post_timing.msecs).to eq(2**31 - 1)
    end
  end

  describe "#timer" do
    context "when a user is not logged in" do
      it "requires authentication" do
        post "/t/#{topic.id}/timer.json", params: { time: "24", status_type: TopicTimer.types[1] }
        expect(response.status).to eq(403)
      end
    end

    context "when does not have permission" do
      it "forbids a user without permission" do
        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: { time: "24", status_type: TopicTimer.types[1] }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
      end
    end

    context "when logged in as a user in the topic timers allowed groups" do
      fab!(:topic_timer_group, :group)
      fab!(:topic_timer_membership) { Fabricate(:group_user, group: topic_timer_group, user: user) }

      before do
        SiteSetting.topic_timers_allowed_groups = topic_timer_group.id.to_s
        sign_in(user)
      end

      it "guards destructive timers but allows ordinary timers for the configured group" do
        topic.update!(slow_mode_seconds: 3600)

        post "/t/#{topic.id}/timer.json", params: { time: "1", status_type: "clear_slow_mode" }

        expect(response.status).to eq(400)
        expect(response.body).to include("status_type")
        expect(topic.reload.slow_mode_seconds).to eq(3600)
        expect(
          TopicTimer.find_by(topic: topic, status_type: TopicTimer.types[:clear_slow_mode]),
        ).to be_nil

        post "/t/#{topic.id}/timer.json", params: { time: "24", status_type: "delete" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
        expect(topic.reload.public_topic_timer).to eq(nil)

        topic.update!(slow_mode_seconds: 0)
        post "/t/#{topic.id}/timer.json", params: { time: "24", status_type: TopicTimer.types[1] }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer.user).to eq(user)
      end
    end

    context "when logged in as an admin" do
      before do
        freeze_time
        sign_in(admin)
      end

      it "validates, creates and deletes time-based topic status updates" do
        post "/t/#{topic.id}/timer.json",
             params: {
               time: 1.day.ago,
               status_type: TopicTimer.types[1],
             }
        expect(response.status).to eq(400)

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "something" }
        expect(response.status).to eq(400)
        expect(response.body).to include("status_type")

        post "/t/#{topic.id}/timer.json", params: { time: 24, status_type: TopicTimer.types[1] }

        expect(response.status).to eq(200)
        topic_status_update = TopicTimer.last
        expect(topic_status_update.topic).to eq(topic)
        expect(topic_status_update.execute_at).to eq_time(24.hours.from_now)

        json = response.parsed_body
        expect(DateTime.parse(json["execute_at"])).to eq_time(
          DateTime.parse(topic_status_update.execute_at.to_s),
        )
        expect(json["duration_minutes"]).to eq(topic_status_update.duration_minutes)
        expect(json["closed"]).to eq(topic.reload.closed)

        post "/t/#{topic.id}/timer.json", params: { time: nil, status_type: TopicTimer.types[1] }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)
        json = response.parsed_body
        expect(json["execute_at"]).to eq(nil)
        expect(json["duration_minutes"]).to eq(nil)
        expect(json["closed"]).to eq(topic.closed)
      end

      it "creates and clears duration-based and category-publishing timers" do
        post "/t/#{topic.id}/timer.json",
             params: {
               duration_minutes: 7200,
               status_type: TopicTimer.types[7],
             }

        expect(response.status).to eq(200)
        topic_status_update = TopicTimer.last
        expect(topic_status_update.topic).to eq(topic)
        expect(topic_status_update.execute_at).to eq_time(5.days.from_now)
        expect(topic_status_update.duration_minutes).to eq(7200)

        json = response.parsed_body
        expect(DateTime.parse(json["execute_at"])).to eq_time(
          DateTime.parse(topic_status_update.execute_at.to_s),
        )
        expect(json["duration_minutes"]).to eq(topic_status_update.duration_minutes)

        post "/t/#{topic.id}/timer.json", params: { time: nil, status_type: TopicTimer.types[7] }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)
        json = response.parsed_body
        expect(json["execute_at"]).to eq(nil)
        expect(json["duration"]).to eq(nil)
        expect(json["closed"]).to eq(topic.closed)

        post "/t/#{topic.id}/timer.json", params: { time: 24, status_type: "publish_to_category" }
        expect(response.status).to eq(404)

        post "/t/#{topic.id}/timer.json",
             params: {
               time: 24,
               status_type: TopicTimer.types[3],
               category_id: topic.category_id,
             }

        expect(response.status).to eq(200)
        topic_status_update = TopicTimer.last
        expect(topic_status_update.topic).to eq(topic)
        expect(topic_status_update.execute_at).to eq_time(24.hours.from_now)
        expect(topic_status_update.status_type).to eq(TopicTimer.types[:publish_to_category])
        expect(response.parsed_body["category_id"]).to eq(topic.category_id)

        post "/t/#{topic.id}/timer.json", params: { time: nil, status_type: "publish_to_category" }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)
      end
    end

    context "when logged in as a TL4 user" do
      before { SiteSetting.enable_category_group_moderation = true }

      it "forbids timers on inaccessible and private message topics" do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)
        pm_topic = Fabricate(:private_message_topic)

        post "/t/#{pm_topic.id}/timer.json",
             params: {
               time: "24",
               status_type: TopicTimer.types[1],
             }
        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")

        sign_in(trust_level_4)
        pm_topic = Fabricate(:private_message_topic, user: trust_level_4)

        post "/t/#{pm_topic.id}/timer.json",
             params: {
               time: 24,
               status_type: "publish_to_category",
               category_id: category.id,
             }
        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
        expect(pm_topic.reload.public_topic_timer).to eq(nil)
      end

      it "forbids publishing to categories the user cannot write to" do
        readers = Fabricate(:group)
        readers.add(trust_level_4)
        read_only_category =
          Fabricate(
            :private_category,
            group: readers,
            permission_type: CategoryGroup.permission_types[:readonly],
          )
        read_only_topic = Fabricate(:topic, category: read_only_category)
        sign_in(trust_level_4)

        post "/t/#{read_only_topic.id}/timer.json",
             params: {
               time: 24,
               status_type: "publish_to_category",
               category_id: category.id,
             }
        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
        expect(read_only_topic.reload.public_topic_timer).to eq(nil)

        staff_only_category = Fabricate(:category)
        staff_only_category.set_permissions(staff: :full)
        staff_only_category.save!

        post "/t/#{topic.id}/timer.json",
             params: {
               time: 24,
               status_type: "publish_to_category",
               category_id: staff_only_category.id,
             }
        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
      end

      it "allows category moderators to manage destructive timers" do
        sign_in(trust_level_4)

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "delete" }
        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "delete_replies" }
        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")

        user.update!(trust_level: TrustLevel[4])
        Group.user_trust_level_change!(user.id, user.trust_level)
        Fabricate(:category_moderation_group, category: topic.category, group: user.groups.first)
        moderated_topic = Fabricate(:topic, category: topic.category, user: user)
        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "delete" }
        expect(response.status).to eq(200)

        post "/t/#{moderated_topic.id}/timer.json",
             params: {
               duration_minutes: 1440,
               status_type: "delete_replies",
             }
        expect(response.status).to eq(200)
        expect(TopicTimer.last.status_type).to eq(TopicTimer.types[:delete_replies])
      end
    end

    context "when logged in as a moderator" do
      it "blocks duration-based publishing to a category the moderator cannot create topics in" do
        sign_in(moderator)

        admin_only_category = Fabricate(:category)
        admin_only_category.set_permissions(admins: :full)
        admin_only_category.save!

        moderator_guardian = Guardian.new(moderator)
        expect(moderator_guardian.can_moderate?(topic)).to eq(true)
        expect(moderator_guardian.can_create_topic_on_category?(admin_only_category)).to eq(false)

        post "/t/#{topic.id}/timer.json",
             params: {
               duration_minutes: 60,
               based_on_last_post: true,
               status_type: "publish_to_category",
               category_id: admin_only_category.id,
             }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
        expect(topic.reload.public_topic_timer).to eq(nil)
      end
    end
  end

  describe "#set_slow_mode" do
    context "when not logged in" do
      it "forbids anonymous users and allows admins" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }
        expect(response.status).to eq(403)

        sign_in(admin)
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        expect(response.status).to eq(200)
        expect(topic.reload.slow_mode_seconds).to eq(3600)
      end
    end

    context "when logged in as a regular user" do
      it "only allows TL4 users to set the slow mode interval" do
        user.update!(trust_level: TrustLevel[3])
        sign_in(user)

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }
        expect(response.status).to eq(403)

        user.update!(trust_level: TrustLevel[4])

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        expect(response.status).to eq(200)
        expect(topic.reload.slow_mode_seconds).to eq(3600)
      end
    end

    context "with auto-disable slow mode" do
      before { sign_in(admin) }

      let!(:timestamp) { 1.week.from_now.to_formatted_s(:iso8601) }

      it "sets, updates and deletes the slow mode timer" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600", enabled_until: timestamp }

        created_timer = TopicTimer.find_by(topic: topic)
        expect(created_timer.execute_at.to_formatted_s(:iso8601)).to eq(timestamp)

        updated_timestamp = 1.hour.from_now.to_formatted_s(:iso8601)
        put "/t/#{topic.id}/slow_mode.json",
            params: {
              seconds: "3600",
              enabled_until: updated_timestamp,
            }

        created_timer = TopicTimer.find_by(topic: topic)
        expect(created_timer.execute_at.to_formatted_s(:iso8601)).to eq(updated_timestamp)

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "0", enabled_until: timestamp }

        expect(TopicTimer.find_by(topic: topic)).to be_nil
      end

      it "returns 400 and changes nothing when enabled_until is in the past" do
        put "/t/#{topic.id}/slow_mode.json",
            params: {
              seconds: "3600",
              enabled_until: 1.hour.ago.to_formatted_s(:iso8601),
            }

        expect(response.status).to eq(400)
        expect(topic.reload.slow_mode_seconds).to eq(0)
      end

      it "returns 400 when seconds is missing" do
        put "/t/#{topic.id}/slow_mode.json", params: { enabled_until: timestamp }

        expect(response.status).to eq(400)
      end
    end

    describe "changes slow mode" do
      before { sign_in(admin) }

      it "creates a staff log entry" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        log = UserHistory.last
        expect(log.acting_user_id).to eq(admin.id)
        expect(log.topic_id).to eq(topic.id)
        expect(log.action).to eq(UserHistory.actions[:topic_slow_mode_set])

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "0" }

        log = UserHistory.last
        expect(log.acting_user_id).to eq(admin.id)
        expect(log.topic_id).to eq(topic.id)
        expect(log.action).to eq(UserHistory.actions[:topic_slow_mode_removed])
      end
    end
  end

  describe "#invite" do
    context "when not logged in" do
      it "requires authentication" do
        post "/t/#{topic.id}/invite.json", params: { email: "jake@adventuretime.ooo" }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in" do
      before { sign_in(user) }

      it "rejects unauthorized, non-private-message, invalid and email-less invites" do
        post "/t/#{pm.id}/invite.json", params: { user: user.username }
        expect(response.status).to eq(403)

        user.update!(trust_level: TrustLevel[2])
        user_topic = Fabricate(:topic, user: user)

        post "/t/#{user_topic.id}/invite.json", params: { email: "someguy@email.com" }
        expect(response.status).to eq(422)

        post "/t/#{user_topic.id}/invite.json"
        expect(response.status).to eq(422)

        topic_id = topic.id
        topic.destroy!
        post "/t/#{topic_id}/invite.json", params: { email: user.email }
        expect(response.status).to eq(404)
      end

      it "enforces the PM recipient cap for users but lets staff bypass it" do
        pm = Fabricate(:private_message_topic, user: user, recipient: post_author1)
        moderator_pm = Fabricate(:private_message_topic, user: moderator, recipient: post_author1)
        SiteSetting.max_allowed_message_recipients = 2

        post "/t/#{pm.id}/invite.json", params: { user: user_2.username }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t(
            "pm_reached_recipients_limit",
            recipients_limit: SiteSetting.max_allowed_message_recipients,
          ),
        )

        sign_in(moderator)
        post "/t/#{moderator_pm.id}/invite.json", params: { user: user_2.username }
        expect(response.status).to eq(200)
        expect(moderator_pm.reload.topic_allowed_users.count).to eq(3)
      end

      it "does not disclose an existing user from email invites" do
        pm = Fabricate(:private_message_topic, user: user, recipient: post_author1)

        post "/t/#{pm.id}/invite.json", params: { email: user_2.email }

        expect(response.status).to eq(422)
        expect(response.parsed_body["failed"]).to eq("FAILED")
        expect(pm.reload.topic_allowed_users.pluck(:user_id)).not_to include(user_2.id)

        post "/t/#{pm.id}/invite.json", params: { email: [user_2.email, "@"] }

        expect(response.status).to eq(422)
        expect(response.parsed_body["failed"]).to eq("FAILED")
        expect(response.body).not_to include(user_2.username)
        expect(pm.reload.topic_allowed_users.pluck(:user_id)).not_to include(user_2.id)
      end

      it "returns generic success without side effects when an authorized email invite matches an existing user" do
        sign_in(admin)
        pm = Fabricate(:private_message_topic, user: admin, recipient: post_author1)
        small_actions =
          pm.posts.where(post_type: Post.types[:small_action], action_code: "invited_user")

        expect do
          post "/t/#{pm.id}/invite.json", params: { email: user_2.email }
        end.to not_change { pm.reload.topic_allowed_users.count }.and not_change {
                small_actions.reload.count
              }.and not_change { Invite.count }.and not_change { EmailLog.count }

        expect(response.status).to eq(200)
        expect(response.parsed_body["success"]).to eq("OK")
        expect(pm.topic_allowed_users.pluck(:user_id)).not_to include(user_2.id)
      end
    end
  end

  describe "#invite_group" do
    let!(:admins) { Group[:admins] }

    def invite_group(topic, expected_status)
      post "/t/#{topic.id}/invite-group.json", params: { group: admins.name }
      expect(response.status).to eq(expected_status)
    end

    before { admins.update!(messageable_level: Group::ALIAS_LEVELS[:everyone]) }

    it "forbids anonymous and non-participants but allows participants" do
      invite_group(pm, 403)

      sign_in(user)
      invite_group(pm, 403)

      pm.allowed_users << user
      invite_group(pm, 200)
      expect(pm.allowed_groups.first.id).to eq(admins.id)
    end

    context "as an admin user" do
      before { sign_in(admin) }

      it "requires a PM and respects notification preferences" do
        invite_group(topic, 422)

        watcher = Fabricate(:user)
        admins.add(watcher)
        admins
          .group_users
          .find_by(user_id: watcher.id)
          .update!(notification_level: NotificationLevels.all[:watching])

        notification_pm = Fabricate(:private_message_topic, user: admin, recipient: post_author1)
        Fabricate(:post, topic: notification_pm, user: admin)
        Notification.delete_all
        Jobs.run_immediately!
        post "/t/#{notification_pm.id}/invite-group.json", params: { group: "admins" }

        expect(response.status).to eq(200)
        expect(notification_pm.allowed_groups.first.id).to eq(admins.id)
        expect(Notification.count).to be > 0

        quiet_pm = Fabricate(:private_message_topic, user: admin, recipient: post_author1)
        Fabricate(:post, topic: quiet_pm, user: admin)
        Notification.delete_all
        post "/t/#{quiet_pm.id}/invite-group.json",
             params: {
               group: "admins",
               should_notify: false,
             }

        expect(response.status).to eq(200)
        expect(Notification.count).to eq(0)
      end
    end

    context "when a watching group member is ignoring the inviter" do
      fab!(:inviter) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:group) { Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]) }
      fab!(:victim, :user)

      before do
        pm.allowed_users << inviter
        Fabricate(:post, topic: pm, user: post_author2)
        group.add(victim)
        group
          .group_users
          .find_by(user_id: victim.id)
          .update!(notification_level: NotificationLevels.all[:watching])
        Fabricate(:ignored_user, user: victim, ignored_user: inviter)
      end

      it "only notifies the ignoring member when the inviter is staff" do
        sign_in(inviter)
        Notification.delete_all
        Jobs.run_immediately!
        post "/t/#{pm.id}/invite-group.json", params: { group: group.name }

        expect(response.status).to eq(200)
        expect(
          Notification.where(
            user_id: victim.id,
            notification_type: Notification.types[:invited_to_private_message],
          ).count,
        ).to eq(0)

        staff_pm = Fabricate(:private_message_topic, user: admin, recipient: post_author1)
        Fabricate(:post, topic: staff_pm, user: post_author2)
        sign_in(admin)
        Notification.delete_all
        post "/t/#{staff_pm.id}/invite-group.json", params: { group: group.name }

        expect(response.status).to eq(200)
        expect(
          Notification.where(
            user_id: victim.id,
            notification_type: Notification.types[:invited_to_private_message],
          ).count,
        ).to eq(1)
      end
    end

    context "when PM has reached maximum allowed numbers of recipients" do
      fab!(:group) { Fabricate(:group, messageable_level: 99) }
      fab!(:pm) { Fabricate(:private_message_topic, user: user, recipient: post_author1) }
      fab!(:moderator_pm) do
        Fabricate(:private_message_topic, user: moderator, recipient: post_author1)
      end

      before { SiteSetting.max_allowed_message_recipients = 2 }

      it "enforces limits for users but lets staff bypass them" do
        post "/t/#{pm.id}/invite-group.json", params: { group: group.name }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t(
            "pm_reached_recipients_limit",
            recipients_limit: SiteSetting.max_allowed_message_recipients,
          ),
        )

        sign_in(moderator)
        post "/t/#{moderator_pm.id}/invite-group.json", params: { group: group.name }
        expect(response.status).to eq(200)
        expect(
          moderator_pm.reload.topic_allowed_users.count + moderator_pm.topic_allowed_groups.count,
        ).to eq(3)
      end
    end
  end

  describe "shared drafts" do
    fab!(:shared_drafts_group, :group)
    fab!(:shared_drafts_member) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:shared_drafts_membership) do
      Fabricate(:group_user, group: shared_drafts_group, user: shared_drafts_member)
    end

    before { SiteSetting.shared_drafts_category = shared_drafts_category.id }

    describe "#update_shared_draft" do
      fab!(:other_cat, :category)
      fab!(:topic) do
        Fabricate(:topic, user: post_author1, category: shared_drafts_category, visible: false)
      end
      fab!(:draft_topic) do
        Fabricate(:topic, user: post_author1, category: shared_drafts_category, visible: false)
      end
      fab!(:shared_draft) { Fabricate(:shared_draft, topic: draft_topic, category: category) }

      it "forbids anonymous users" do
        put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
        expect(response.code.to_i).to eq(403)
      end

      it "lets moderators update drafts only inside the shared drafts category" do
        sign_in(moderator)
        put "/t/#{draft_topic.id}/shared-draft.json", params: { category_id: other_cat.id }
        expect(response.status).to eq(200)
        expect(draft_topic.reload.shared_draft.category_id).to eq(other_cat.id)

        put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
        expect(response.status).to eq(200)
        expect(topic.reload.shared_draft.category_id).to eq(other_cat.id)

        ordinary_topic = Fabricate(:topic, user: post_author1, category: category)

        put "/t/#{ordinary_topic.id}/shared-draft.json", params: { category_id: other_cat.id }

        expect(response.status).to eq(403)
        expect(ordinary_topic.reload.shared_draft).to be_nil
      end

      context "as a non-staff shared-draft group member" do
        before do
          SiteSetting.shared_drafts_allowed_groups = shared_drafts_group.id.to_s
          sign_in(shared_drafts_member)
        end

        it "updates existing drafts but not editable or moved-in topics" do
          put "/t/#{draft_topic.id}/shared-draft.json", params: { category_id: other_cat.id }

          expect(response.status).to eq(200)
          expect(draft_topic.reload.shared_draft.category_id).to eq(other_cat.id)

          own_topic = Fabricate(:topic, category: category, user: shared_drafts_member)
          Fabricate(:post, topic: own_topic, user: shared_drafts_member)

          put "/t/#{own_topic.id}/shared-draft.json", params: { category_id: category.id }

          expect(response.status).to eq(403)
          expect(own_topic.reload.shared_draft).to be_nil

          put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }

          expect(response.status).to eq(403)
          expect(topic.reload.shared_draft).to be_nil
        end
      end
    end

    describe "#publish" do
      fab!(:topic) do
        Fabricate(:topic, user: post_author1, category: shared_drafts_category, visible: false)
      end
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "forbids anonymous and regular users" do
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)

        sign_in(user)
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      context "as staff" do
        before { sign_in(moderator) }

        it "publishes and restricts reloads while rejecting the shared drafts destination" do
          Fabricate(:shared_draft, topic: topic, category: category)

          put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
          expect(response.status).to eq(200)
          json = response.parsed_body["basic_topic"]
          result = Topic.find(json["id"])
          expect(result.category_id).to eq(category.id)
          expect(result.visible).to eq(true)

          restricted_group = Fabricate(:group)
          restricted_category = Fabricate(:private_category, group: restricted_group)
          excluded_user = Fabricate(:user)
          restricted_group.add(moderator)
          restricted_topic =
            Fabricate(:topic, user: post_author1, category: shared_drafts_category, visible: false)
          Fabricate(:post, user: post_author1, topic: restricted_topic)
          Fabricate(:shared_draft, topic: restricted_topic, category: category)

          messages =
            MessageBus.track_publish("/topic/#{restricted_topic.id}") do
              put "/t/#{restricted_topic.id}/publish.json",
                  params: {
                    destination_category_id: restricted_category.id,
                  }
            end

          expect(response.status).to eq(200)
          expect(response.parsed_body["basic_topic"]["id"]).to eq(restricted_topic.id)
          expect(excluded_user.guardian.can_see?(restricted_topic.reload)).to eq(false)
          reload_message =
            messages.find { |message| message.data == { reload_topic: true, refresh_stream: true } }
          expect(reload_message).to be_present
          expect(reload_message.group_ids).to contain_exactly(restricted_group.id)

          shared_draft_topic =
            Fabricate(:topic, user: post_author1, category: shared_drafts_category, visible: false)
          Fabricate(:post, user: post_author1, topic: shared_draft_topic)
          Fabricate(:shared_draft, topic: shared_draft_topic, category: category)

          put "/t/#{shared_draft_topic.id}/publish.json",
              params: {
                destination_category_id: shared_drafts_category.id,
              }
          expect(response.status).to eq(400)
        end
      end

      context "as a non-staff shared-draft group member" do
        before do
          SiteSetting.shared_drafts_allowed_groups = shared_drafts_group.id.to_s
          sign_in(shared_drafts_member)
        end

        it "publishes editable drafts and denies drafts the member cannot edit" do
          Fabricate(:shared_draft, topic: topic, category: category)

          put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }

          expect(response.status).to eq(200)
          expect(topic.reload.category_id).to eq(category.id)
          expect(topic.visible).to eq(true)

          denied_topic =
            Fabricate(:topic, user: post_author1, category: shared_drafts_category, visible: false)
          denied_post = Fabricate(:post, user: post_author1, topic: denied_topic)
          Fabricate(:shared_draft, topic: denied_topic, category: category)
          topic_timer =
            Fabricate(
              :topic_timer,
              topic: denied_topic,
              status_type: TopicTimer.types[:publish_to_category],
              category_id: category.id,
            )

          SiteSetting.editing_grace_period = 0
          PostRevisor.new(denied_post).revise!(post_author1, raw: "an important revision")
          shared_drafts_category.set_permissions(shared_drafts_group => :readonly)
          shared_drafts_category.save!

          put "/t/#{denied_topic.id}/publish.json", params: { destination_category_id: category.id }

          expect(response.status).to eq(403)
          expect(denied_topic.reload.category_id).to eq(shared_drafts_category.id)
          expect(denied_topic.visible).to eq(false)
          expect(denied_post.reload.revisions.count).to eq(1)
          expect(topic_timer.reload.deleted_at).to be_nil
        end
      end

      context "when the topic is not a shared draft" do
        fab!(:destination_cat, :category)
        fab!(:own_topic) { Fabricate(:topic, category: category, user: shared_drafts_member) }
        fab!(:own_post) { Fabricate(:post, topic: own_topic, user: shared_drafts_member) }

        before do
          SiteSetting.editing_grace_period = 0
          SiteSetting.shared_drafts_allowed_groups = shared_drafts_group.id.to_s
          PostRevisor.new(own_post).revise!(moderator, raw: "an important revision")
          own_topic.update_status("visible", false, moderator)
          sign_in(shared_drafts_member)
        end

        it "does not publish a topic that is not a shared draft" do
          put "/t/#{own_topic.id}/publish.json",
              params: {
                destination_category_id: destination_cat.id,
              }

          expect(response.status).to eq(403)
          expect(own_topic.reload.category_id).to eq(category.id)
          expect(own_topic.visible).to eq(false)
          expect(own_post.reload.revisions.count).to eq(1)

          put "/t/#{own_topic.id}/shared-draft.json", params: { category_id: category.id }
          put "/t/#{own_topic.id}/publish.json", params: { destination_category_id: category.id }

          expect(response.status).to eq(403)
          expect(own_topic.reload.visible).to eq(false)
          expect(own_post.reload.revisions.count).to eq(1)
        end
      end
    end
  end

  describe "crawler" do
    it "preloads the topic when a crawler requests the desktop layout" do
      get topic.relative_url,
          headers: {
            "User-Agent" => "Googlebot",
            "Discourse-Render" => "desktop",
          }

      expect(response.status).to eq(200)
      expect(response.body).to have_tag("script#data-preloaded") do |element|
        preloaded = JSON.parse(element.current_scope.text)
        expect(JSON.parse(preloaded["topic_#{topic.id}"])["id"]).to eq(topic.id)
      end
    end

    it "renders posts without preloaded data when a browser requests the crawler layout" do
      post = Fabricate(:post, topic: topic, user: post_author1)

      get topic.relative_url,
          headers: {
            "User-Agent" => "Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36",
            "Discourse-Render" => "crawler",
          }

      expect(response.status).to eq(200)
      expect(response.body).to have_tag(:body, with: { class: "crawler" })
      expect(response.body).to include(post.cooked)
      expect(response.body).not_to have_tag("script#data-preloaded")
    end

    context "when not a crawler" do
      it "renders with the application layout" do
        get topic.relative_url

        body = response.body

        expect(body).to have_tag(:script, with: { "data-discourse-entrypoint" => "discourse" })
        expect(body).to have_tag(:meta, with: { name: "fragment" })
        expect(body).to have_tag("script#data-preloaded") do |element|
          preloaded = JSON.parse(element.current_scope.text)
          expect(JSON.parse(preloaded["topic_#{topic.id}"])["id"]).to eq(topic.id)
        end
      end

      it "renders the excerpt in the meta description decoded exactly once and tag-free" do
        topic.update!(
          excerpt:
            %(Tom &amp; Jerry&#39;s <span class="hashtag-icon-placeholder"></span>tale&hellip; "><script>alert(1)</script>),
        )

        get topic.relative_url

        expect(response.body).not_to include("<script>alert(1)</script>")
        meta = Nokogiri::HTML5.parse(response.body).at("meta[name='description']")
        expect(meta["content"]).to eq(%(Tom & Jerry's tale… ">alert(1)))
      end
    end

    context "with a tagged personal message rendered in the crawler layout" do
      fab!(:participant) { Fabricate(:user, refresh_auto_groups: true) }
      fab!(:pm_tag, :tag)
      fab!(:pm) { Fabricate(:private_message_topic, user: user, recipient: participant) }
      fab!(:pm_post) { Fabricate(:post, topic: pm, user: user) }

      before do
        SiteSetting.tagging_enabled = true
        pm.tags << pm_tag
      end

      it "includes PM tags in the print view only when the participant can tag PMs" do
        sign_in(participant)

        get "#{pm.relative_url}/print"

        expect(response.status).to eq(200)
        expect(response.body).not_to include(pm_tag.name)

        SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:trust_level_0]

        get "#{pm.relative_url}/print"

        expect(response.status).to eq(200)
        expect(response.body).to include(pm_tag.name)
      end
    end

    context "when a crawler" do
      fab!(:page1_time) { 3.months.ago }
      fab!(:page2_time) { 2.months.ago }
      fab!(:page3_time) { 1.month.ago }

      fab!(:page_1_posts) do
        Fabricate.times(
          4,
          :post,
          user: post_author2,
          topic: topic,
          created_at: page1_time,
          updated_at: page1_time,
        )
      end

      fab!(:page_2_posts) do
        Fabricate.times(
          4,
          :post,
          user: post_author3,
          topic: topic,
          created_at: page2_time,
          updated_at: page2_time,
        )
      end

      fab!(:page_3_posts) do
        Fabricate.times(
          2,
          :post,
          user: post_author3,
          topic: topic,
          created_at: page3_time,
          updated_at: page3_time,
        )
      end

      before { TopicView.stubs(:chunk_size).returns(4) }

      let(:bot_user_agent) do
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
      end

      it "renders with the crawler layout, and handles proper pagination" do
        get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

        body = response.body

        expect(body).to have_tag(:body, with: { class: "crawler" })
        expect(body).to_not have_tag(:meta, with: { name: "fragment" })
        expect(body).to include('<link rel="next" href="' + topic.relative_url + "?page=2")

        expect(body).to include("id='post_1'")
        expect(body).to include("id='post_2'")

        expect(response.headers["Last-Modified"]).to eq(page1_time.httpdate)

        get topic.relative_url + "?page=2", env: { "HTTP_USER_AGENT" => bot_user_agent }
        body = response.body

        expect(response.headers["Last-Modified"]).to eq(page2_time.httpdate)

        expect(body).to include("id='post_5'")
        expect(body).to include("id='post_6'")

        expect(body).to include('<link rel="prev" href="' + topic.relative_url)
        expect(body).to include('<link rel="next" href="' + topic.relative_url + "?page=3")

        get topic.relative_url + "?page=3", env: { "HTTP_USER_AGENT" => bot_user_agent }
        body = response.body

        page_3_posts.each { |post| expect(body).to include(post.cooked) }

        expect(response.headers["Last-Modified"]).to eq(page3_time.httpdate)
        expect(body).to include('<link rel="prev" href="' + topic.relative_url + "?page=2")
      end

      it "escapes the excerpt exactly once in the schema.org text meta" do
        topic.update!(excerpt: %(Tom &amp; Jerry&hellip; "><script>alert(1)</script>))

        get topic.relative_url + "?page=2", env: { "HTTP_USER_AGENT" => bot_user_agent }

        expect(response.body).not_to include("<script>alert(1)</script>")
        meta = Nokogiri::HTML5.parse(response.body).at("meta[itemprop='text']")
        expect(meta["content"]).to eq(%(Tom & Jerry… ">alert(1)))
      end

      it "only renders one post for non-canonical post-specific URLs" do
        get "#{topic.relative_url}/6"
        expect(response.body).to have_tag("#post_6")
        expect(response.body).not_to have_tag("#post_5")
        expect(response.body).not_to have_tag("#post_7")
        expect(response.body).not_to have_tag("a", with: { rel: "next" })
        expect(response.body).not_to have_tag("a", with: { rel: "prev" })
        expect(response.body).to have_tag(
          "a",
          text: I18n.t("show_post_in_topic"),
          with: {
            href: "#{topic.relative_url}?page=2#post_6",
          },
        )
      end

      it "includes top-level author metadata when the view does not include the OP naturally" do
        get "#{topic.relative_url}/2"
        expect(body).to have_tag(
          "[itemtype='http://schema.org/DiscussionForumPosting'] > [itemprop='author']",
        )

        get "#{topic.relative_url}/7"
        expect(body).to have_tag(
          "[itemtype='http://schema.org/DiscussionForumPosting'] > [itemprop='author']",
        )

        get "#{topic.relative_url}?page=2"
        expect(body).to have_tag(
          "[itemtype='http://schema.org/DiscussionForumPosting'] > [itemprop='author']",
        )
      end

      it "works even when the author has been deleted" do
        topic.update!(user_id: nil)

        get "#{topic.relative_url}/2"
      end

      it "adds breadcrumbs to the correct subcategory and category url in subfolder" do
        set_subfolder "/subpath"

        subcategory = Fabricate(:category, parent_category_id: category.id)
        topic.update!(category: subcategory)

        get "/t/#{topic.slug}/#{topic.id}",
            env: {
              "HTTP_USER_AGENT" => "Mozilla/5.0 ...",
              "HTTP_VIA" => "HTTP/1.0 web.archive.org",
            }
        expect(response.body).to have_tag(
          "a",
          with: {
            href: subcategory.url,
          },
          text: subcategory.name,
        )
        expect(response.body).to have_tag("a", with: { href: category.url }, text: category.name)
      end

      describe "BreadcrumbList structured data" do
        def breadcrumb_list_items
          Nokogiri
            .HTML5(response.body)
            .css(
              "[itemtype='http://schema.org/BreadcrumbList'] > [itemtype='http://schema.org/ListItem']",
            )
            .map do |item|
              name = item.at_css("[itemprop='name']")
              {
                position: item.at_css("[itemprop='position']")["content"],
                name: name["content"] || name.text.strip,
                item: item.at_css("[itemprop='item']")["href"],
              }
            end
        end

        it "includes the topic in top-level breadcrumbs but not category metadata" do
          topic.update!(category: category)

          get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

          expect(breadcrumb_list_items).to eq(
            [
              { position: "1", name: category.name, item: category.url },
              { position: "2", name: topic.title, item: topic.url },
            ],
          )
          expect(response.body).to have_tag(
            "meta[property='og:article:section']",
            count: 1,
            with: {
              content: category.name,
            },
          )
        end

        it "renders the full category chain and emoji titles, omitting uncategorized breadcrumbs" do
          subcategory = Fabricate(:category, parent_category: category)
          topic.update!(category: subcategory)

          get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

          expect(breadcrumb_list_items).to eq(
            [
              { position: "1", name: category.name, item: category.url },
              { position: "2", name: subcategory.name, item: subcategory.url },
              { position: "3", name: topic.title, item: topic.url },
            ],
          )

          topic.update!(category: category, title: "Breadcrumbs are great :tada:")

          get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

          expect(breadcrumb_list_items.last[:name]).to eq("Breadcrumbs are great 🎉")

          topic.update!(category_id: SiteSetting.uncategorized_category_id)

          get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

          expect(response.body).not_to have_tag("[itemtype='http://schema.org/BreadcrumbList']")
        end
      end

      context "with canonical_url" do
        fab!(:topic_embed) { Fabricate(:topic_embed, embed_url: "https://markvanlan.com") }

        it "uses the embedded URL as canonical only when configured" do
          get topic_embed.topic.url, env: { "HTTP_USER_AGENT" => bot_user_agent }
          expect(response.body).to include('<link rel="canonical" href="' + topic_embed.topic.url)

          SiteSetting.embed_set_canonical_url = true
          get topic_embed.topic.url, env: { "HTTP_USER_AGENT" => bot_user_agent }
          expect(response.body).to include('<link rel="canonical" href="' + topic_embed.embed_url)
        end
      end

      context "with wayback machine" do
        it "renders crawler layout" do
          get topic.relative_url,
              env: {
                "HTTP_USER_AGENT" =>
                  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/74.0.3729.169 Safari/537.36",
                "HTTP_VIA" => "HTTP/1.0 web.archive.org (Wayback Save Page)",
              }
          body = response.body

          expect(body).to have_tag(:body, with: { class: "crawler" })
          expect(body).to_not have_tag(:meta, with: { name: "fragment" })
        end
      end

      context "when content localization is enabled" do
        fab!(:category) { Fabricate(:category, locale: "en") }
        fab!(:subcategory) { Fabricate(:category, parent_category: category, locale: "en") }
        fab!(:tag)

        fab!(:source_post_localizations) do
          topic.update!(category: subcategory, tags: [tag], locale: "en")
          topic
            .posts
            .order(:post_number)
            .limit(3)
            .map do |post|
              post.update!(locale: "en")
              Fabricate(:post_localization, post:, locale: "de")
            end
        end
        fab!(:ja_topic) { Fabricate(:topic_localization, topic:, locale: "ja") }
        fab!(:ja_category) { Fabricate(:category_localization, category:, locale: "ja") }
        fab!(:ja_subcategory) do
          Fabricate(:category_localization, category: subcategory, locale: "ja")
        end
        fab!(:ja_posts) do
          topic
            .posts
            .where("post_number < 4")
            .map { |post| Fabricate(:post_localization, post:, locale: "ja") }
        end

        before do
          SiteSetting.content_localization_enabled = true
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_param = true
        end

        describe "when tl param is absent" do
          fab!(:pt_topic) { Fabricate(:topic_localization, topic:, locale: "pt") }
          fab!(:pt_category) { Fabricate(:category_localization, category:, locale: "pt") }
          fab!(:pt_subcategory) do
            Fabricate(:category_localization, category: subcategory, locale: "pt")
          end
          fab!(:pt_first_post) do
            Fabricate(:post_localization, post: topic.first_post, locale: "pt_BR")
          end

          it "localizes to the default locale when available and falls back to the source otherwise" do
            SiteSetting.default_locale = "pt"

            get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

            expect(response.body).to include(pt_topic.title)
            expect(response.body).to include(pt_category.name)
            expect(response.body).to include(pt_subcategory.name)
            expect(response.body).to include(pt_first_post.cooked)

            SiteSetting.default_locale = "es"

            get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

            expect(response.body).to include(topic.title)
            expect(response.body).to include(category.name)
            expect(response.body).to include(subcategory.name)
            expect(response.body).to include(topic.first_post.cooked)
          end

          it "localizes forced crawler HTML while respecting translation opt-out" do
            SiteSetting.default_locale = "pt"
            headers = {
              "User-Agent" => "Mozilla/5.0 Chrome/130.0.0.0 Safari/537.36",
              "Discourse-Render" => "crawler",
            }

            get topic.relative_url, headers: headers

            document = Nokogiri.HTML5(response.body)
            expect(document.at_css("#post_1 .post").text).to include(
              Nokogiri::HTML5.fragment(pt_first_post.cooked).text,
            )

            cookies[ContentLocalization::AUTOMATICALLY_TRANSLATE_COOKIE] = "false"
            get topic.relative_url, headers: headers

            document = Nokogiri.HTML5(response.body)
            expect(document.at_css("#post_1 .post").text).to include(
              Nokogiri::HTML5.fragment(topic.first_post.cooked).text,
            )
          end
        end

        describe "when tl param is present ?tl=ja" do
          it "localizes crawler titles and breadcrumbs with a cached fancy title" do
            topic.update_column(:fancy_title, Topic.fancy_title(topic.title))

            get topic.relative_url,
                env: {
                  "HTTP_USER_AGENT" => bot_user_agent,
                },
                params: {
                  tl: "ja",
                }

            expect(response.status).to eq(200)
            expect(Nokogiri.HTML5(response.body).at_css("title").text).to start_with(ja_topic.title)
            expect(response.body).to include(ja_category.name)
            expect(response.body).to include(ja_subcategory.name)
          end

          it "does not persist a localized fancy title when the source cache is missing" do
            topic.update_column(:fancy_title, nil)

            get topic.relative_url,
                env: {
                  "HTTP_USER_AGENT" => bot_user_agent,
                },
                params: {
                  tl: "ja",
                }

            expect(response.status).to eq(200)
            expect(Nokogiri.HTML5(response.body).at_css("title").text).to start_with(ja_topic.title)
            expect(Topic.where(id: topic.id).pick(:fancy_title)).not_to eq(
              Topic.fancy_title(ja_topic.title),
            )
          end
        end

        it "does not have N+1s when loading localizations" do
          initial_sql_queries =
            track_sql_queries do
              get topic.relative_url,
                  env: {
                    "HTTP_USER_AGENT" => bot_user_agent,
                  },
                  params: {
                    tl: "ja",
                  }
              expect(response.status).to eq(200)
            end.select { |q| q.include?("_localizations") }.count

          fourth_post = topic.posts.find_by!(post_number: 4)
          fourth_post.update!(locale: "en")
          fourth_post_localization = Fabricate(:post_localization, post: fourth_post, locale: "ja")

          new_sql_queries =
            track_sql_queries do
              get topic.relative_url,
                  env: {
                    "HTTP_USER_AGENT" => bot_user_agent,
                  },
                  params: {
                    tl: "ja",
                  }
              expect(response.status).to eq(200)
            end.select { |q| q.include?("_localizations") }.count

          expect(response.body).to have_tag("#post_4")
          expect(response.body).to include(fourth_post_localization.cooked)
          expect(new_sql_queries).to eq(initial_sql_queries)
        end
      end
    end
  end

  describe "#reset_bump_date" do
    context "with errors" do
      it "requires an authorized user" do
        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(403)

        sign_in(user)
        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(403)
      end

      it "denies access for TL4 user on a topic in a restricted category" do
        restricted_topic = Fabricate(:topic, category: staff_category, user: post_author1)
        sign_in(trust_level_4)
        put "/t/#{restricted_topic.id}/reset-bump-date.json"
        expect(response.status).to eq(403)
      end
    end

    it "lets administrators, moderators and TL4 users reset to the last post timestamp" do
      timestamp = 1.day.ago
      Fabricate(:post, user: post_author1, topic: topic, created_at: timestamp)

      [admin, moderator, trust_level_4].each do |acting_user|
        sign_in(acting_user)
        topic.update!(bumped_at: 1.hour.ago)

        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(200), acting_user.username
        expect(topic.reload.bumped_at).to eq_time(timestamp), acting_user.username
      end
    end

    context "when an admin selects a post" do
      before { sign_in(admin) }

      it "handles missing topics and posts and resets to the selected post timestamp" do
        max_id = Topic.maximum(:id)
        put "/t/#{max_id + 1}/reset-bump-date.json"
        expect(response.status).to eq(404)

        id = (SecureRandom.random_number * 100_000_000).to_i
        original_bumped_at = topic.bumped_at

        put "/t/#{topic.id}/reset-bump-date/#{id}.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to eq_time(original_bumped_at)

        post1 = Fabricate(:post, user: post_author1, topic: topic, created_at: 2.days.ago)
        _post2 = Fabricate(:post, user: post_author1, topic: topic, created_at: 1.day.ago)

        put "/t/#{topic.id}/reset-bump-date/#{post1.id}.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to eq_time(post1.created_at)
      end
    end
  end

  describe "#private_message_reset_new" do
    fab!(:group) do
      Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap { |g| g.add(user_2) }
    end

    fab!(:group_message) do
      create_post(
        user: user,
        target_group_names: [group.name],
        archetype: Archetype.private_message,
      ).topic
    end

    fab!(:private_message) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    fab!(:private_message_2) do
      create_post(
        user: user,
        target_usernames: [user_2.username],
        archetype: Archetype.private_message,
      ).topic
    end

    before { sign_in(user_2) }

    it "rejects missing inboxes, unknown groups and invalid topic_ids" do
      put "/topics/pm-reset-new.json"
      expect(response.status).to eq(400)

      put "/topics/pm-reset-new.json", params: { inbox: "group", group_name: "randomgroup" }
      expect(response.status).to eq(404)

      put "/topics/pm-reset-new.json", params: { topic_ids: "1" }
      expect(response.status).to eq(400)
      expect(DismissedTopicUser.count).to eq(0)
    end

    it "returns the right response when trying to reset new private messages of a restricted group" do
      sign_in(user)

      put "/topics/pm-reset-new.json", params: { inbox: "group", group_name: group.name }

      expect(response.status).to eq(404)
    end

    it "can reset all new group private messages" do
      put "/topics/pm-reset-new.json", params: { inbox: "group", group_name: group.name }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(group_message.id)

      expect(DismissedTopicUser.count).to eq(1)

      expect(DismissedTopicUser.exists?(topic: group_message, user: user_2)).to eq(true)
    end

    it "can reset new personal private messages" do
      put "/topics/pm-reset-new.json", params: { inbox: "user" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_ids"]).to contain_exactly(
        private_message.id,
        private_message_2.id,
      )

      expect(DismissedTopicUser.count).to eq(2)

      expect(
        DismissedTopicUser.exists?(user: user_2, topic: [private_message, private_message_2]),
      ).to eq(true)
    end

    it "can reset new personal and group private messages" do
      stub_const(TopicQuery, "DEFAULT_PER_PAGE_COUNT", 1) do
        put "/topics/pm-reset-new.json", params: { inbox: "all" }

        expect(response.status).to eq(200)

        expect(DismissedTopicUser.count).to eq(3)

        expect(
          DismissedTopicUser.exists?(
            user: user_2,
            topic: [private_message, private_message_2, group_message],
          ),
        ).to eq(true)
      end
    end

    it "can reset new private messages from given topic ids" do
      put "/topics/pm-reset-new.json", params: { topic_ids: [group_message.id, "12345"] }

      expect(response.status).to eq(200)

      expect(DismissedTopicUser.count).to eq(1)

      expect(DismissedTopicUser.exists?(topic: group_message, user: user_2)).to eq(true)

      put "/topics/pm-reset-new.json", params: { topic_ids: [private_message.id, "12345"] }

      expect(response.status).to eq(200)

      expect(DismissedTopicUser.exists?(topic: private_message, user: user_2)).to eq(true)
    end
  end

  describe "#archive_message and #move_to_inbox" do
    fab!(:group) do
      Fabricate(:group, messageable_level: Group::ALIAS_LEVELS[:everyone]).tap { |g| g.add(user) }
    end

    fab!(:group_message) do
      create_post(
        user: user,
        target_group_names: [group.name],
        archetype: Archetype.private_message,
      ).topic
    end

    it "archives a private message" do
      sign_in(user)

      message =
        MessageBus
          .track_publish(PrivateMessageTopicTrackingState.group_channel(group.id)) do
            put "/t/#{group_message.id}/archive-message.json"

            expect(response.status).to eq(200)
          end
          .first

      expect(message.data["message_type"]).to eq(
        PrivateMessageTopicTrackingState::GROUP_ARCHIVE_MESSAGE_TYPE,
      )

      expect(message.data["payload"]["acting_user_id"]).to eq(user.id)

      body = response.parsed_body

      expect(body["group_name"]).to eq(group.name)
    end

    it "hides the message from non-participants for both inbox operations" do
      sign_in(user_2)

      put "/t/#{group_message.id}/archive-message.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
      expect(GroupArchivedMessage.exists?(group: group, topic: group_message)).to eq(false)

      put "/t/#{group_message.id}/move-to-inbox.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
    end
  end

  describe "#set_notifications" do
    let(:watching) { NotificationLevels.topic_levels[:watching] }

    it "rejects session impersonation and hides inaccessible topics without changing notifications" do
      restricted_topic = Fabricate(:topic, category: staff_category, user: post_author1)
      sign_in(user)
      post "/t/#{topic.id}/notifications.json",
           params: {
             username: user_2.username,
             notification_level: watching,
           }

      expect(response.status).to eq(403)
      expect(TopicUser.find_by(user: user, topic: topic)).to be_blank
      expect(TopicUser.find_by(user: user_2, topic: topic)).to be_blank

      post "/t/#{pm.id}/notifications.json", params: { notification_level: watching }

      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
      expect(TopicUser.find_by(user: user, topic: pm)).to be_blank

      post "/t/#{restricted_topic.id}/notifications.json", params: { notification_level: watching }

      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
      expect(TopicUser.find_by(user: user, topic: restricted_topic)).to be_blank
    end

    describe "via API" do
      it "lets an admin target another user or default to self" do
        api_key = Fabricate(:api_key, user: admin).key
        headers = { HTTP_API_KEY: api_key, HTTP_API_USERNAME: admin.username }
        post "/t/#{topic.id}/notifications",
             params: {
               username: user.username,
               notification_level: watching,
             },
             headers: headers

        expect(TopicUser.find_by(user: user, topic: topic).notification_level).to eq(watching)
        expect(TopicUser.find_by(user: admin, topic: topic)).to be_blank

        post "/t/#{topic.id}/notifications",
             params: {
               notification_level: watching,
             },
             headers: headers

        expect(TopicUser.find_by(user: admin, topic: topic).notification_level).to eq(watching)
      end

      it "rejects non-admin impersonation but defaults to self" do
        api_key = Fabricate(:api_key, user: user).key
        headers = { HTTP_API_KEY: api_key, HTTP_API_USERNAME: user.username }
        post "/t/#{topic.id}/notifications",
             params: {
               username: user_2.username,
               notification_level: watching,
             },
             headers: headers

        expect(response.status).to eq(403)
        expect(TopicUser.find_by(user: user, topic: topic)).to be_blank
        expect(TopicUser.find_by(user: user_2, topic: topic)).to be_blank

        post "/t/#{topic.id}/notifications",
             params: {
               notification_level: watching,
             },
             headers: headers

        expect(TopicUser.find_by(user: user, topic: topic).notification_level).to eq(watching)
      end
    end
  end

  describe ".defer_topic_view" do
    before { Jobs.run_immediately! }

    it "does nothing if topic does not exist" do
      topic.destroy!
      expect {
        Scheduler::Defer.capture_later do
          TopicsController.defer_topic_view(topic.id, "1.2.3.4", user.id)
        end
      }.not_to change { TopicViewItem.count }
    end

    it "does nothing if user from ID does not exist" do
      user.destroy!
      expect {
        Scheduler::Defer.capture_later do
          TopicsController.defer_topic_view(topic.id, "1.2.3.4", user.id)
        end
      }.not_to change { TopicViewItem.count }
    end

    it "does nothing if the topic is a shared draft" do
      topic.shared_draft = Fabricate(:shared_draft)

      expect {
        Scheduler::Defer.capture_later do
          TopicsController.defer_topic_view(topic.id, "1.2.3.4", user.id)
        end
      }.not_to change { TopicViewItem.count }
    end

    it "does nothing if user cannot see topic" do
      topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))

      expect {
        Scheduler::Defer.capture_later do
          TopicsController.defer_topic_view(topic.id, "1.2.3.4", user.id)
        end
      }.not_to change { TopicViewItem.count }
    end

    it "creates a topic view" do
      expect {
        Scheduler::Defer.capture_later do
          TopicsController.defer_topic_view(topic.id, "1.2.3.4", user.id)
        end
      }.to change { TopicViewItem.count }
    end
  end

  describe "allow_embed_mode" do
    before { SiteSetting.embed_full_app = true }

    it "keeps framing protection and ignores classes unless embedding is allowed" do
      get("/t/#{topic.slug}/#{topic.id}", params: { class_name: "lee-af" })
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
      expect(response.body).not_to match(/<html[^>]*\blee-af\b/)

      get("/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" })
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end

    it "allows an embeddable host only while full-app embedding is enabled" do
      Fabricate(:embeddable_host, host: "example.com")
      get(
        "/t/#{topic.slug}/#{topic.id}",
        params: {
          embed_mode: "true",
        },
        headers: {
          "HTTP_REFERER" => "https://example.com/page",
        },
      )
      expect(response.headers).not_to include("X-Frame-Options")

      SiteSetting.embed_full_app = false
      get(
        "/t/#{topic.slug}/#{topic.id}",
        params: {
          embed_mode: "true",
        },
        headers: {
          "HTTP_REFERER" => "https://example.com/page",
        },
      )
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end

    it "allows any-origin embedding while accepting only safe HTML classes" do
      SiteSetting.embed_any_origin = true
      get("/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true", class_name: "lee-af" })
      expect(response.headers).not_to include("X-Frame-Options")
      expect(response.body).to match(/<html[^>]*\bclass="[^"]*\blee-af\b/)

      get(
        "/t/#{topic.slug}/#{topic.id}",
        params: {
          embed_mode: "true",
          class_name: "lee\" onload=alert(1)",
        },
      )
      expect(response.body).not_to include("onload=alert(1)")
    end
  end

  describe "third-party analytics in embed mode" do
    before do
      SiteSetting.embed_full_app = true
      SiteSetting.gtm_container_id = "GTM-ABCDEF"
      SiteSetting.adobe_analytics_tags_url = "https://assets.adobedtm.com/launch-EN.min.js"
    end

    def parsed_body
      Nokogiri::HTML5.fragment(response.body)
    end

    it "suppresses analytics only when embedding with suppression enabled" do
      get "/t/#{topic.slug}/#{topic.id}"
      expect(parsed_body.css("#data-google-tag-manager")).to be_present
      expect(
        parsed_body.css("script[src='https://assets.adobedtm.com/launch-EN.min.js']"),
      ).to be_present

      get "/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" }
      expect(parsed_body.css("#data-google-tag-manager")).to be_empty
      expect(
        parsed_body.css("script[src='https://assets.adobedtm.com/launch-EN.min.js']"),
      ).to be_empty

      SiteSetting.suppress_third_party_analytics_in_embed = false
      get "/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" }
      expect(parsed_body.css("#data-google-tag-manager")).to be_present
      expect(
        parsed_body.css("script[src='https://assets.adobedtm.com/launch-EN.min.js']"),
      ).to be_present
    end
  end
end
