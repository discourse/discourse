Warning: truncated output (original token count: 73254)
Total output lines: 8469

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
    fab!(:another_topic) { Fabricate(:topic, title: "Another topic by me") }

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

        post "/t/#{topic.id}/move-posts.json",
             params: {
               title: "blah",
               post_ids: [p1.post_number, p2.post_number],
             }

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

        describe "with freeze_original param" do
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

      context "with failure" do
        it "returns JSON with a false success" do
          sign_in(moderator)
          post "/t/#{topic.id}/move-posts.json", params: { post_ids: [p2.id] }
          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(false)
          expect(result["url"]).to be_blank
        end
      end

      describe "moving replied posts" do
        context "with success" do
          it "moves the child posts too" do
            sign_in(moderator)
            p1 = Fabricate(:post, topic: topic, user: moderator)
            p2 =
              Fabricate(:post, topic: topic, user: moderator, reply_to_post_number: p1.post_number)
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
      end
    end

    describe "moving to a new topic as a group moderator" do
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: topic) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

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

      it "does not allow posts to be moved to a private category" do
        post "/t/#{topic.id}/move-posts.json",
             params: {
               title: "Logan is a good movie",
               post_ids: [p2.id],
               category_id: staff_category.id,
             }

        expect(response).to be_forbidden
      end

      it "ignores unrelated post IDs without exposing their reviewables" do
        restricted_category = Fabricate(:private_category, group: Fabricate(:group))
        restricted_topic = Fabricate(:topic, category: restricted_category)
        restricted_post = Fabricate(:post, topic: restricted_topic)
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

      it "does not allow posts outside of the category to be moved" do
        topic.update!(category: nil)

        post "/t/#{topic.id}/move-posts.json",
             params: {
               title: "blah",
               post_ids: [p1.post_number, p2.post_number],
             }

        expect(response).to be_forbidden
      end
    end

    describe "moving to an existing topic" do
      before { sign_in(moderator) }

      fab!(:p1) { Fabricate(:post, user: moderator) }
      fab!(:topic) { p1.topic }
      fab!(:p2) { Fabricate(:post, user: moderator, topic: topic) }

      context "with success" do
        it "returns success" do
          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 destination_topic_id: dest_topic.id,
               }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to be_present
        end

        describe "moving a post to a restricted topic" do
          fab!(:post_author) { Fabricate(:user, last_seen_at: 1.minute.ago) }
          fab!(:source_topic) { Fabricate(:topic, user: post_author) }
          fab!(:source_post) { Fabricate(:post, topic: source_topic, user: post_author) }
          fab!(:restricted_destination_category) do
            Fabricate(:private_category, group: Group[:staff])
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

        describe "with freeze_original param" do
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

        it "triggers an event on merge" do
          called = false

          assert = ->(original_topic, destination_topic) do
            called = true
            expect(original_topic).to eq(topic)
            expect(destination_topic).to eq(dest_topic)
          end

          DiscourseEvent.on(:topic_merged, &assert)

          post "/t/#{topic.id}/move-posts.json",
               params: {
                 post_ids: [p2.id],
                 destination_topic_id: dest_topic.id,
               }

          expect(called).to eq(true)
          expect(response.status).to eq(200)
        ensure
          DiscourseEvent.off(:topic_merged, &assert)
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
    end

    describe "moving to an existing topic in a read-only category as TL4" do
      fab!(:readonly_category) do
        Fabricate(:category).tap do |c|
          c.set_permissions(everyone: :readonly, staff: :full)
          c.save!
        end
      end
      fab!(:source_topic, :topic)
      fab!(:source_post) { Fabricate(:post, topic: source_topic, user: trust_level_4) }
      fab!(:dest_topic_in_readonly) { Fabricate(:topic, category: readonly_category) }

      before { sign_in(trust_level_4) }

      it "is forbidden" do
        post "/t/#{source_topic.id}/move-posts.json",
             params: {
               post_ids: [source_post.id],
               destination_topic_id: dest_topic_in_readonly.id,
             }

        expect(response).to be_forbidden
      end
    end

    describe "moving to an existing topic in a category with restricted write permissions as TL4" do
      fab!(:group)
      fab!(:restricted_write_category) do
        Fabricate(:category).tap do |c|
          c.set_permissions(group => :full, :everyone => :readonly)
          c.save!
        end
      end
      fab!(:source_topic, :topic)
      fab!(:source_post) { Fabricate(:post, topic: source_topic, user: trust_level_4) }
      fab!(:dest_topic_restricted) { Fabricate(:topic, category: restricted_write_category) }

      before { sign_in(trust_level_4) }

      it "is forbidden" do
        post "/t/#{source_topic.id}/move-posts.json",
             params: {
               post_ids: [source_post.id],
               destination_topic_id: dest_topic_restricted.id,
             }

        expect(response).to be_forbidden
      end
    end

    describe "moving chronologically to an existing topic" do
      before { sign_in(moderator) }

      fab!(:p1) { Fabricate(:post, user: moderator, created_at: dest_topic.created_at - 1.hour) }
      fab!(:topic) { p1.topic }

      context "with success" do
        it "returns success" do
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

    describe "moving to an existing topic as a group moderator" do
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) { Fabricate(:post, user: user, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: user, post_number: 2, topic: topic) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
        post "/t/#{topic.id}/move-posts.json",
             params: {
               post_ids: [p2.id],
               destination_topic_id: dest_topic.id,
             }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end

      it "does not allow posts to be moved to a private category" do
        dest_topic.update!(category: staff_category)

        post "/t/#{topic.id}/move-posts.json",
             params: {
               post_ids: [p2.id],
               destination_topic_id: dest_topic.id,
             }

        expect(response).to be_forbidden
      end

      it "does not allow posts outside of the category to be moved" do
        topic.update!(category: nil)

        post "/t/#{topic.id}/move-posts.json",
             params: {
               post_ids: [p1.post_number, p2.post_number],
               destination_topic_id: dest_topic.id,
             }

        expect(response).to be_forbidden
      end
    end

    describe "moving chronologically to an existing topic as a group moderator" do
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) do
        Fabricate(:post, user: user, topic: topic, created_at: dest_topic.created_at - 1.hour)
      end

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
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
               post_ids: [p1.post_number, p2.post_number],
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
    end

    describe "moving chronologically to an existing message" do
      before { sign_in(admin) }

      fab!(:evil_trout)
      fab!(:message) { pm }

      fab!(:dest_message) do
        Fabricate(
          :private_message_topic,
          user: trust_level_4,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: evil_trout)],
        )
      end

      fab!(:p2) do
        Fabricate(
          :post,
          user: evil_trout,
          post_number: 2,
          topic: message,
          created_at: dest_message.created_at - 1.hour,
        )
      end

      context "with success" do
        it "returns success" do
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
  end

  describe "#merge_topic" do
    it "needs you to be logged in" do
      post "/t/111/merge-topic.json", params: { destination_topic_id: 345 }
      expect(response.status).to eq(403)
    end

    describe "merging into another topic" do
      fab!(:p1) { Fabricate(:post, user: user) }
      fab!(:topic) { p1.topic }

      it "raises an error without destination_topic_id" do
        sign_in(moderator)
        post "/t/#{topic.id}/merge-topic.json"
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to merge" do
        sign_in(user)
        post "/t/111/merge-topic.json", params: { destination_topic_id: 345 }
        expect(response).to be_forbidden
      end

      context "when moving all the posts to the destination topic" do
        it "returns success" do
          sign_in(moderator)
          post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

          expect(response.status).to eq(200)
          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to be_present
        end
      end
    end

    describe "merging chronologically into another topic" do
      fab!(:p1) { Fabricate(:post, user: user, created_at: dest_topic.created_at - 1.hour) }
      fab!(:topic) { p1.topic }

      context "when moving all the posts to the destination topic" do
        it "returns success" do
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
    end

    describe "merging into another topic as a group moderator" do
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) { Fabricate(:post, user: post_author1, post_number: 1, topic: topic) }
      fab!(:p2) { Fabricate(:post, user: post_author2, post_number: 2, topic: topic) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response.status).to eq(200)
        result = response.parsed_body
        expect(result["success"]).to eq(true)
        expect(result["url"]).to be_present
      end

      it "does not allow posts to be moved to a private category" do
        dest_topic.update!(category: staff_category)

        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response).to be_forbidden
      end

      it "does not allow posts outside of the category to be moved" do
        topic.update!(category: nil)

        post "/t/#{topic.id}/merge-topic.json", params: { destination_topic_id: dest_topic.id }

        expect(response).to be_forbidden
      end
    end

    describe "merging chronologically into another topic as a group moderator" do
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:p1) do
        Fabricate(
          :post,
          user: post_author1,
          post_number: 1,
          topic: topic,
          created_at: dest_topic.created_at - 1.hour,
        )
      end
      fab!(:p2) do
        Fabricate(
          :post,
          user: post_author2,
          post_number: 2,
          topic: topic,
          created_at: dest_topic.created_at - 30.minutes,
        )
      end

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "moves the posts" do
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
      fab!(:message) { Fabricate(:private_message_topic, user: user) }
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

      it "raises an error without destination_topic_id" do
        sign_in(moderator)
        post "/t/#{message.id}/merge-topic.json", params: { archetype: "private_message" }
        expect(response.status).to eq(400)
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

      context "when moving all the posts to the destination message" do
        it "returns success" do
          sign_in(moderator)
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
      end
    end

    describe "merging chronologically into another message" do
      fab!(:message) { Fabricate(:private_message_topic, user: user) }

      fab!(:dest_message) do
        Fabricate(
          :private_message_topic,
          user: trust_level_4,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: moderator)],
        )
      end

      fab!(:p1) do
        Fabricate(
          :post,
          topic: message,
          user: trust_level_4,
          created_at: dest_message.created_at - 1.hour,
        )
      end
      fab!(:p2) do
        Fabricate(
          :post,
          topic: message,
          reply_to_post_number: p1.post_number,
          user: user,
          created_at: dest_message.created_at - 30.minutes,
        )
      end

      context "when moving all the posts to the destination message" do
        it "returns success" do
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

      fab!(:allowed_group, :group)
      fab!(:allowed_group_user) { Fabricate(:user, groups: [allowed_group]) }

      describe "moderator signed in" do
        let!(:editor) { sign_in(moderator) }

        it "returns 200 when moderators_change_post_ownership is true" do
          SiteSetting.moderators_change_post_ownership = true

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          expect(response.status).to eq(200)
        end

        it "returns 403 when moderators_change_post_ownership is false" do
          SiteSetting.moderators_change_post_ownership = false

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               }
          expect(response.status).to eq(403)
        end
      end

      describe "admin signed in" do
        let!(:editor) { sign_in(admin) }

        it "raises an error with a parameter missing" do
          [{ post_ids: [1, 2, 3] }, { username: "user_a" }].each do |params|
            post "/t/111/change-owner.json", params: params
            expect(response.status).to eq(400)
          end
        end

        it "changes the topic and posts ownership" do
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
        end

        it "changes multiple posts" do
          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id, p2.id],
               }

          expect(response.status).to eq(200)

          p1.reload
          p2.reload

          expect(p1.user).to_not eq(nil)
          expect(p1.reload.user).to eq(p2.reload.user)
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
        fab!(:allowed_group, :group)
        fab!(:allowed_group_user) { Fabricate(:user, groups: [allowed_group]) }
        fab!(:topic_allowed_user_can_see) { Fabricate(:topic, category: category) }
        fab!(:post_allowed_user_can_see) { Fabricate(:post, topic: topic_allowed_user_can_see) }

        before { sign_in(allowed_group_user) }

        it "returns 200 when group is allow listed" do
          SiteSetting.change_post_ownership_allowed_groups = "#{allowed_group.id}"

          post "/t/#{topic_allowed_user_can_see.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [post_allowed_user_can_see.id],
               }
          expect(response.status).to eq(200)
        end

        it "returns 403 when group is not allow listed" do
          SiteSetting.change_post_ownership_allowed_groups = ""

          post "/t/#{topic_allowed_user_can_see.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [post_allowed_user_can_see.id],
               }
          expect(response.status).to eq(403)
        end
      end

      context "with API key" do
        let(:api_key) { Fabricate(:api_key, user: admin, created_by: admin) }

        it "allows changing ownership with change_owner scope" do
          ApiKeyScope.create!(resource: "topics", action: "change_owner", api_key_id: api_key.id)

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               },
               headers: {
                 "HTTP_API_KEY" => api_key.key,
                 "HTTP_API_USERNAME" => api_key.user.username,
               }

          expect(response.status).to eq(200)
          expect(p1.reload.user).to eq(user_a)
        end

        it "denies access without change_owner scope" do
          ApiKeyScope.create!(resource: "topics", action: "read", api_key_id: api_key.id)

          post "/t/#{topic.id}/change-owner.json",
               params: {
                 username: user_a.username_lower,
                 post_ids: [p1.id],
               },
               headers: {
                 "HTTP_API_KEY" => api_key.key,
                 "HTTP_API_USERNAME" => api_key.user.username,
               }

          expect(response.status).to eq(403)
        end
      end

      describe "private messages" do
        fab!(:private_category) do
          Fabricate(
            :private_category,
            group: Fabricate(:group),
            permission_type: CategoryGroup.permission_types[:full],
          )
        end
        fab!(:private_topic) { Fabricate(:topic, category: private_category) }
        fab!(:private_post) { Fabricate(:post, topic: private_topic) }

        fab!(:pm_user, :user)
        fab!(:pm_topic) { Fabricate(:private_message_topic, user: pm_user) }
        fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: pm_user) }

        describe "moderator signed in" do
          before do
            SiteSetting.moderators_change_post_ownership = true
            sign_in(moderator)
          end

          it "returns 403 for topics in private categories the moderator cannot see" do
            post "/t/#{private_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [private_post.id],
                 }
            expect(response.status).to eq(403)
          end

          it "returns 403 for private messages the moderator is not a participant of" do
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

          it "can change ownership of posts in private messages" do
            post "/t/#{pm_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [pm_post.id],
                 }
            expect(response.status).to eq(200)
            expect(pm_post.reload.user).to eq(user_a)
          end

          it "can change ownership of posts in private categories" do
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
          fab!(:pm_topic_allowed_user_can_see) do
            Fabricate(:private_message_topic, user: allowed_group_user)
          end
          fab!(:pm_post_allowed_user_can_see) do
            Fabricate(:post, topic: pm_topic_allowed_user_can_see, user: allowed_group_user)
          end

          before do
            SiteSetting.change_post_ownership_allowed_groups = "#{allowed_group.id}"
            sign_in(allowed_group_user)
          end

          it "returns 200 for visible PM" do
            post "/t/#{pm_topic_allowed_user_can_see.id}/change-owner.json",
                 params: {
                   username: user_a.username_lower,
                   post_ids: [pm_post_allowed_user_can_see.id],
                 }
            expect(response.status).to eq(200)
          end

          it "returns 403 for not visible PM" do
            post "/t/#{pm_topic.id}/change-owner.json",
                 params: {
                   username: user_a.username,
                   post_ids: [pm_post.id],
                 }
            expect(response.status).to eq(403)
          end

          it "returns 403 for post in private category" do
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
      let!(:topic) { Fabricate(:topic, created_at: old_timestamp) }
      let!(:p1) { Fabricate(:post, user: post_author1, topic: topic, created_at: old_timestamp) }
      let!(:p2) do
        Fabricate(:post, user: post_author2, topic: topic, created_at: old_timestamp + 1.day)
      end

      it "updates timestamps for the selected posts" do
        # try to see if we fail with invalid first
        put "/t/1/change-timestamp.json"
        expect(response.status).to eq(400)

        put "/t/#{topic.id}/change-timestamp.json", params: { timestamp: new_timestamp.to_f }

        expect(response.status).to eq(200)
        expect(topic.reload.created_at).to eq_time(new_timestamp)
        expect(p1.reload.created_at).to eq_time(new_timestamp)
        expect(p2.reload.created_at).to eq_time(old_timestamp)
      end

      it "creates a staff log entry" do
        put "/t/#{topic.id}/change-timestamp.json", params: { timestamp: new_timestamp.to_f }

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

      describe "when the user can see the topic" do
        it "clears the topic pin" do
          expect do put "/t/#{topic.id}/clear-pin.json" end.to change {
            TopicUser.where(topic_id: topic.id, user_id: user.id).count
          }.by(1)
          expect(response.status).to eq(200)
        end
      end
    end
  end

  describe "#status" do
    it "needs you to be logged in" do
      put "/t/1/status.json", params: { status: "visible", enabled: true }
      expect(response.status).to eq(403)
    end

    describe "when logged in as a moderator" do
      before { sign_in(moderator) }

      it "raises an exception if you can't change it" do
        sign_in(user)
        put "/t/#{topic.id}/status.json", params: { status: "visible", enabled: "true" }
        expect(response).to be_forbidden
      end

      it "requires the status parameter" do
        put "/t/#{topic.id}/status.json", params: { enabled: true }
        expect(response.status).to eq(400)
      end

      it "requires the enabled parameter" do
        put "/t/#{topic.id}/status.json", params: { status: "visible" }
        expect(response.status).to eq(400)
      end

      it "raises an error with a status not in the allowlist" do
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
      fab!(:category)
      fab!(:category_moderation_group) do
        Fabricate(:category_moderation_group, category:, group: group_user.group)
      end
      fab!(:topic) { Fabricate(:topic, category: category) }

      before do
        sign_in(user)
        SiteSetting.enable_category_group_moderation = true
      end

      it "allows a group moderator to close a topic" do
        put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "true" }

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(true)
        expect(topic.posts.last.action_code).to eq("closed.enabled")
      end

      it "allows a group moderator to reopen a topic" do
        topic.update!(closed: true)

        expect do
          put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "false" }
        end.to change { topic.reload.posts.count }.by(1)

        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(false)
        expect(topic.posts.last.action_code).to eq("closed.disabled")
      end

      it "allows a group moderator to archive a topic" do
        expect do
          put "/t/#{topic.id}/status.json", params: { status: "archived", enabled: "true" }
        end.to change { topic.reload.posts.count }.by(1)

        expect(response.status).to eq(200)
        expect(topic.reload.archived).to eq(true)
        expect(topic.posts.last.action_code).to eq("archived.enabled")
      end

      it "allows a group moderator to unarchive a topic" do
        topic.update!(archived: true)

        put "/t/#{topic.id}/status.json", params: { status: "archived", enabled: "false" }

        expect(response.status).to eq(200)
        expect(topic.reload.archived).to eq(false)
        expect(topic.posts.last.action_code).to eq("archived.disabled")
      end

      it "allows a group moderator to pin a topic" do
        put "/t/#{topic.id}/status.json",
            params: {
              status: "pinned",
              enabled: "true",
              until: 2.weeks.from_now,
            }

        expect(response.status).to eq(200)
        expect(topic.reload.pinned_at).to_not eq(nil)
      end

      it "allows a group moderator to unpin a topic" do
        put "/t/#{topic.id}/status.json", params: { status: "pinned", enabled: "false" }

        expect(response.status).to eq(200)
        expect(topic.reload.pinned_at).to eq(nil)
      end

      it "allows a group moderator to unlist a topic" do
        put "/t/#{topic.id}/status.json", params: { status: "visible", enabled: "false" }

        expect(response.status).to eq(200)
        expect(topic.reload.visible).to eq(false)
        expect(topic.reload.visibility_reason_id).to eq(
          Topic.visibility_reasons[:manually_unlisted],
        )
        expect(topic.posts.last.action_code).to eq("visible.disabled")
      end

      it "allows a group moderator to relist a topic" do
        topic.update!(visible: false)

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
      before { sign_in(trust_level_4) }

      it "allows TL4 to close visible topics" do
        put "/t/#{topic.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(200)
        expect(topic.reload.closed).to eq(true)
      end

      it "prevents TL4 from closing restricted category topics" do
        staff_topic = Fabricate(:topic, category: staff_category)
        put "/t/#{staff_topic.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.closed).to eq(false)
      end

      it "prevents TL4 from closing private messages" do
        pm = Fabricate(:private_message_topic)
        put "/t/#{pm.id}/status.json", params: { status: "closed", enabled: "true" }
        expect(response.status).to eq(403)
        expect(pm.reload.closed).to eq(false)
      end

      it "prevents TL4 from archiving restricted topics" do
        staff_topic = Fabricate(:topic, category: staff_category)
        put "/t/#{staff_topic.id}/status.json", params: { status: "archived", enabled: "true" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.archived).to eq(false)
      end

      it "prevents TL4 from pinning restricted topics" do
        staff_topic = Fabricate(:topic, category: staff_category)
        put "/t/#{staff_topic.id}/status.json", params: { status: "pinned", enabled: "true" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.pinned_at).to eq(nil)
      end

      it "prevents TL4 from toggling visibility of restricted topics" do
        staff_topic = Fabricate(:topic, category: staff_category)
        put "/t/#{staff_topic.id}/status.json", params: { status: "visible", enabled: "false" }
        expect(response.status).to eq(403)
        expect(staff_topic.reload.visible).to eq(true)
      end
    end

    context "with API key" do
      let(:api_key) { Fabricate(:api_key, user: moderator, created_by: moderator) }

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

        it "fails to update topic status in an unpermitted category" do
          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
                category_id: tracked_category.id,
              },
              headers: {
                "HTTP_API_KEY" => api_key.key,
                "HTTP_API_USERNAME" => api_key.user.username,
              }

          expect(response.status).to eq(403)
          expect(response.body).to include(I18n.t("invalid_access"))
          expect(topic.reload.closed).to eq(false)
        end

        it "fails without a category_id" do
          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
              },
              headers: {
                "HTTP_API_KEY" => api_key.key,
                "HTTP_API_USERNAME" => api_key.user.username,
              }

          expect(response.status).to eq(403)
          expect(response.body).to include(I18n.t("invalid_access"))
          expect(topic.reload.closed).to eq(false)
        end

        it "updates topic status in a permitted category" do
          put "/t/#{topic.id}/status.json",
              params: {
                status: "closed",
                enabled: "true",
                category_id: topic.category_id,
              },
              headers: {
                "HTTP_API_KEY" => api_key.key,
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
                "HTTP_API_KEY" => api_key.key,
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
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      private_post = Fabricate(:post, topic: private_topic)
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

    context "for last post only" do
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
      let!(:topic) { Fabricate(:topic, user: user, deleted_at: Time.now, deleted_by: moderator) }
      let!(:post) do
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

      context "when logged in as a category group moderator who cannot see the topic" do
        fab!(:mod_group, :group)
        fab!(:cat_mod_user, :user)
        fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:private_topic) do
          Fabricate(:topic, category: private_category, deleted_at: Time.now, deleted_by: moderator)
        end
        fab!(:private_post) do
          Fabricate(
            :post,
            topic: private_topic,
            post_number: 1,
            deleted_at: Time.now,
            deleted_by: moderator,
          )
        end

        before do
          SiteSetting.enable_category_group_moderation = true
          Fabricate(:category_moderation_group, category: private_category, group: mod_group)
          mod_group.add(cat_mod_user)
          sign_in(cat_mod_user)
        end

        it "prevents recovering a topic the user cannot see" do
          put "/t/#{private_topic.id}/recover.json"

          expect(response).to be_forbidden
          expect(private_topic.reload.trashed?).to be_truthy
        end
      end

      context "when logged in as a category group moderator who can see the topic" do
        fab!(:mod_group, :group)
        fab!(:cat_mod_user, :user)
        fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:private_topic) do
          Fabricate(:topic, category: private_category, deleted_at: Time.now, deleted_by: moderator)
        end
        fab!(:private_post) do
          Fabricate(
            :post,
            topic: private_topic,
            post_number: 1,
            deleted_at: Time.now,
            deleted_by: moderator,
          )
        end

        before do
          SiteSetting.enable_category_group_moderation = true
          private_category.set_permissions(mod_group => :full)
          private_category.save!
          Fabricate(:category_moderation_group, category: private_category, group: mod_group)
          mod_group.add(cat_mod_user)
          sign_in(cat_mod_user)
        end

        it "allows recovering a topic the user can see" do
          put "/t/#{private_topic.id}/recover.json"

          expect(response.status).to eq(200)
          expect(private_topic.reload.trashed?).to be_falsey
        end
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

      context "when logged in as a category group moderator who cannot see the topic" do
        fab!(:mod_group, :group)
        fab!(:cat_mod_user, :user)
        fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:private_topic) { Fabricate(:topic, category: private_category) }
        fab!(:private_post) { Fabricate(:post, topic: private_topic, user: user, post_number: 1) }

        before do
          SiteSetting.enable_category_group_moderation = true
          Fabricate(:category_moderation_group, category: private_category, group: mod_group)
          mod_group.add(cat_mod_user)
          sign_in(cat_mod_user)
        end

        it "prevents deleting a topic the user cannot see" do
          delete "/t/#{private_topic.id}.json"

          expect(response.status).to eq(422)
          expect(private_topic.reload.trashed?).to be_falsey
        end
      end

      context "when logged in as a category group moderator who can see the topic" do
        fab!(:mod_group, :group)
        fab!(:cat_mod_user, :user)
        fab!(:private_category) { Fabricate(:private_category, group: Fabricate(:group)) }
        fab!(:private_topic) { Fabricate(:topic, category: private_category) }
        fab!(:private_post) { Fabricate(:post, topic: private_topic, user: user, post_number: 1) }

        before do
          SiteSetting.enable_category_group_moderation = true
          private_category.set_permissions(mod_group => :full)
          private_category.save!
          Fabricate(:category_moderation_group, category: private_category, group: mod_group)
          mod_group.add(cat_mod_user)
          sign_in(cat_mod_user)
        end

        it "allows deleting a topic the user can see" do
          delete "/t/#{private_topic.id}.json"

          expect(response.status).to eq(200)
          expect(private_topic.reload.trashed?).to be_truthy
        end
      end
    end

    describe "force destroy" do
      fab!(:post) { Fabricate(:post, topic: topic, post_number: 1) }

      before do
        SiteSetting.can_permanently_delete = true

        sign_in(admin)
      end

      it "force destroys all deleted small actions in topic too" do
        small_action_post = Fabricate(:small_action, topic: topic)
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
      end

      it "creates a log and clean up previously recorded sensitive information" do
        small_action_post = Fabricate(:small_action, topic: topic)
        PostDestroyer.new(Discourse.system_user, post, context: "Automated testing").destroy
        PostDestroyer.new(
          Discourse.system_user,
          small_action_post,
          context: "Automated testing",
        ).destroy

        delete "/t/#{topic.id}.json", params: { force_destroy: true }

        expect(response.status).to eq(200)

        expect(UserHistory.last).to have_attributes(
          action: UserHistory.actions[:delete_topic_permanently],
          acting_user_id: admin.id,
        )

        expect(UserHistory.where(topic_id: topic.id, details: "(permanently deleted)").count).to eq(
          2,
        )
      end

      it "does not allow to destroy topic if not all posts were force destroyed" do
        _other_post = Fabricate(:post, topic: topic, post_number: 2)
        PostDestroyer.new(Discourse.system_user, post, context: "Automated testing").destroy

        delete "/t/#{topic.id}.json", params: { force_destroy: true }

        expect(response.status).to eq(403)
      end

      it "does not allow to destroy topic if not all small action posts were deleted" do
        small_action_post = Fabricate(:small_action, topic: topic)
        PostDestroyer.new(
          Discourse.system_user,
          small_action_post,
          context: "Automated testing",
        ).destroy

        delete "/t/#{topic.id}.json", params: { force_destroy: true }

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#id_for_slug" do
    fab!(:topic) { Fabricate(:post, user: post_author1).topic }

    it "returns JSON for the slug" do
      get "/t/id_for/#{topic.slug}.json"
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["topic_id"]).to eq(topic.id)
      expect(json["url"]).to eq(topic.url)
      expect(json["slug"]).to eq(topic.slug)
    end

    it "returns invalid access if the user can't see the topic" do
      get "/t/id_for/#{pm.slug}.json"
      expect(response).to be_forbidden
    end
  end

  describe "#update" do
    it "does not update a topic for an anonymous user" do
      put "/t/1.json", params: { slug: "xyz" }
      expect(response.status).to eq(403)
    end

    describe "when logged in" do
      fab!(:topic) { Fabricate(:topic, user: user) }

      before_all { Fabricate(:post, user: post_author1, topic: topic) }

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

      context "when updating shared drafts" do
        fab!(:topic) { Fabricate(:topic, category: shared_drafts_category) }
        fab!(:shared_draft) do
          Fabricate(:shared_draft, topic: topic, category: Fabricate(:category))
        end

        it "changes destination category" do
          put "/t/#{topic.id}.json", params: { category_id: category.id }

          expect(response.status).to eq(403)
          expect(topic.shared_draft.category_id).not_to eq(category.id)
        end
      end

      it "does not allow a regular user to change archetype to banner" do
        put "/t/#{topic.id}.json", params: { archetype: Archetype.banner }

        topic.reload
        expect(topic.archetype).to eq(Archetype.default)
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

      describe "without permission" do
        it "raises an exception when the user doesn't have permission to update the topic" do
          topic.update!(archived: true)
          put "/t/#{topic.slug}/#{topic.id}.json"

          expect(response.status).to eq(403)
        end
      end

      context "with permission" do
        fab!(:post_hook, :post_web_hook)
        fab!(:topic_hook, :topic_we…33254 tokens truncated…"message_type"]).to eq(
              TopicTrackingState::DISMISS_NEW_MESSAGE_TYPE,
            )
            expect(messages[0].data["payload"]["topic_ids"]).to eq([topic_in_private_category.id])
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq(
              [topic_in_private_category.id],
            )
          end
        end
      end

      context "with tag" do
        fab!(:tag_topic, :topic)
        fab!(:topic_tag) { Fabricate(:topic_tag, topic: tag_topic, tag: tag) }

        it "dismisses topics for tag" do
          TopicTrackingState.expects(:publish_dismiss_new).with(user.id, topic_ids: [tag_topic.id])
          put "/topics/reset-new.json?tag_name=#{tag.name}", params: { dismiss_topics: true }
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq([tag_topic.id])
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

          it "respects the tag param and only dismisses topics tagged with this tag if the user can see it" do
            group.add(user)
            messages =
              MessageBus.track_publish do
                put "/topics/reset-new.json",
                    params: {
                      dismiss_topics: true,
                      tag_name: restricted_tag.name,
                    }
              end
            expect(messages.size).to eq(1)
            expect(messages[0].data["payload"]["topic_ids"]).to contain_exactly(
              topic_with_restricted_tag.id,
            )
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to contain_exactly(
              topic_with_restricted_tag.id,
            )
          end

          it "ignores the tag param and dismisses all topics if the user can't see the tag" do
            messages =
              MessageBus.track_publish do
                put "/topics/reset-new.json",
                    params: {
                      dismiss_topics: true,
                      tag_name: restricted_tag.name,
                    }
              end
            expect(messages.size).to eq(1)
            expect(messages[0].data["payload"]["topic_ids"]).to contain_exactly(
              topic_with_restricted_tag.id,
              tag_topic.id,
              topic_without_tag.id,
            )
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to contain_exactly(
              topic_with_restricted_tag.id,
              tag_topic.id,
              topic_without_tag.id,
            )
          end
        end
      end

      context "with tag and category" do
        fab!(:tag_topic, :topic)
        fab!(:topic_tag) { Fabricate(:topic_tag, topic: tag_topic, tag: tag) }
        fab!(:tag_and_category_topic) { Fabricate(:topic, category: category) }
        fab!(:topic_tag2) { Fabricate(:topic_tag, topic: tag_and_category_topic, tag: tag) }

        it "dismisses topics for tag" do
          TopicTrackingState.expects(:publish_dismiss_new).with(
            user.id,
            topic_ids: [tag_and_category_topic.id],
          )
          put "/topics/reset-new.json?tag_name=#{tag.name}&category_id=#{category.id}",
              params: {
                dismiss_topics: true,
              }
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq(
            [tag_and_category_topic.id],
          )
        end
      end

      context "with specific topics" do
        fab!(:topic2, :topic)
        fab!(:topic3, :topic)

        it "updates the `new_since` date" do
          TopicTrackingState
            .expects(:publish_dismiss_new)
            .with(user.id, topic_ids: [topic2.id, topic3.id])
            .at_least_once

          put "/topics/reset-new.json",
              **{ params: { dismiss_topics: true, topic_ids: [topic2.id, topic3.id] } }
          expect(response.status).to eq(200)
          user.reload
          expect(user.user_stat.new_since.to_date).not_to eq(old_date.to_date)
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to match_array(
            [topic2.id, topic3.id],
          )
        end

        it "raises an error if topic_ids is provided and it is not an array" do
          put "/topics/reset-new.json", params: { topic_ids: topic2.id }
          expect(response.parsed_body["errors"].first).to match(
            /Expecting topic_ids to contain a list/,
          )
          put "/topics/reset-new.json", params: { topic_ids: [topic2.id] }
          expect(response.parsed_body["errors"]).to eq(nil)
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
          expect(messages[0].data["message_type"]).to eq(
            TopicTrackingState::DISMISS_NEW_MESSAGE_TYPE,
          )
          expect(messages[0].data["payload"]["topic_ids"]).to eq([topic3.id])
          expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to eq([topic3.id])
        end

        describe "when tracked param is true" do
          it "does not update user_stat.new_since and does not dismiss untracked topics" do
            put "/topics/reset-new.json?tracked=true",
                **{ params: { topic_ids: [topic2.id, topic3.id] } }
            expect(response.status).to eq(200)
            user.reload
            expect(user.user_stat.new_since.to_date).to eq(old_date.to_date)
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to be_empty
          end

          it "creates topic user records for each unread topic" do
            tracked_topic = create_post.topic
            tracked_topic.update!(category_id: tracked_category.id)
            topic2.update!(category_id: tracked_category.id)

            create_post # This is a new post, but is not tracked so a record will not be created for it
            expect do
              put "/topics/reset-new.json?tracked=true",
                  **{
                    params: {
                      dismiss_topics: true,
                      topic_ids: [tracked_topic.id, topic2.id, topic3.id],
                    },
                  }
            end.to change { DismissedTopicUser.where(user_id: user.id).count }.by(2)
            expect(DismissedTopicUser.where(user_id: user.id).pluck(:topic_id)).to match_array(
              [tracked_topic.id, topic2.id],
            )
          end
        end
      end
    end

    describe "new and unread" do
      fab!(:group)
      fab!(:new_topic, :topic)
      fab!(:unread_topic) { Fabricate(:topic, highest_post_number: 3) }
      fab!(:topic_user) do
        Fabricate(
          :topic_user,
          topic: unread_topic,
          user: user,
          notification_level: NotificationLevels.topic_levels[:tracking],
          last_read_post_number: 1,
        )
      end

      before do
        create_post(topic: unread_topic)
        create_post(topic: unread_topic)
        SiteSetting.enable_unified_new = true
        sign_in(user)
      end

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
        fab!(:category)
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
        fab!(:tag)
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

  describe "#feature_stats" do
    fab!(:category_for_stats, :category)
    fab!(:pinned_in_category_topic) do
      Fabricate(:topic, category: category_for_stats, pinned_at: 1.hour.ago, pinned_globally: false)
    end
    fab!(:globally_pinned_topic) { Fabricate(:topic, pinned_at: 1.hour.ago, pinned_globally: true) }
    fab!(:banner_topic) { Fabricate(:topic, archetype: Archetype.banner) }

    it "returns category and global pin counts when category_id is provided" do
      get "/topics/feature_stats.json", params: { category_id: category_for_stats.id }

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["pinned_in_category_count"]).to eq(1)
      expect(json["pinned_globally_count"]).to eq(1)
      expect(json["banner_count"]).to eq(1)
    end

    it "returns only global pin and banner counts when category_id is omitted" do
      get "/topics/feature_stats.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json).not_to have_key("pinned_in_category_count")
      expect(json["pinned_globally_count"]).to eq(1)
      expect(json["banner_count"]).to eq(1)
    end

    it "allows unlisted banner topic" do
      banner_topic.update!(visible: false)

      get "/topics/feature_stats.json", params: { category_id: category_for_stats.id }
      json = response.parsed_body
      expect(json["banner_count"]).to eq(1)
    end

    it "does not count topics in read-restricted categories for anonymous users" do
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
    it "can correctly get excerpts" do
      first_post =
        create_post(raw: "This is the first post :)", title: "This is a test title I am making yay")
      second_post = create_post(raw: "This is second post", topic: first_post.topic)
      third_post = first_post.topic.add_small_action(first_post.user, "autobumped")

      random_post = Fabricate(:post, user: post_author1)

      get "/t/#{first_post.topic_id}/excerpts.json",
          params: {
            post_ids: [first_post.id, second_post.id, third_post.id, random_post.id],
          }

      json = response.parsed_body
      json.sort! { |a, b| a["post_id"] <=> b["post_id"] }

      # no random post
      expect(json.map { |p| p["post_id"] }).to contain_exactly(
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
    end

    it "does not return whisper posts to non-staff users" do
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

      json = response.parsed_body
      expect(json.map { |p| p["post_id"] }).to contain_exactly(first_post.id)
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

      it "raises an error when the user doesn't have permission to convert topic" do
        sign_in(user)
        put "/t/#{topic.id}/convert-topic/private.json"
        expect(response).to be_forbidden
      end

      context "when the PM recipient cap would be exceeded" do
        fab!(:reply_1) { Fabricate(:post, topic: topic, user: post_author1, post_number: 2) }
        fab!(:reply_2) { Fabricate(:post, topic: topic, user: post_author2, post_number: 3) }

        before { SiteSetting.max_allowed_message_recipients = 2 }

        it "returns an error" do
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
      end

      context "with success" do
        it "returns success" do
          sign_in(admin)
          put "/t/#{topic.id}/convert-topic/private.json"

          topic.reload
          expect(topic.archetype).to eq(Archetype.private_message)
          expect(response.status).to eq(200)

          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to be_present
        end
      end
    end

    describe "converting private message to public topic" do
      fab!(:topic) { Fabricate(:private_message_topic, user: user) }
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "raises an error when the user doesn't have permission to convert topic" do
        sign_in(user)
        put "/t/#{topic.id}/convert-topic/public.json"
        expect(response).to be_forbidden
      end

      it "raises an error when a moderator doesn't have permission to convert topic" do
        sign_in(moderator)
        put "/t/#{topic.id}/convert-topic/public.json"
        expect(response).to be_forbidden
      end

      context "with success" do
        it "returns success and the new url" do
          sign_in(admin)
          put "/t/#{topic.id}/convert-topic/public.json?category_id=#{category.id}"

          topic.reload
          expect(topic.archetype).to eq(Archetype.default)
          expect(topic.category_id).to eq(category.id)
          expect(response.status).to eq(200)

          result = response.parsed_body
          expect(result["success"]).to eq(true)
          expect(result["url"]).to be_present
        end
      end

      context "with some errors" do
        it "returns the error messages" do
          existing_topic = Fabricate(:topic, title: topic.title, category: category)

          sign_in(admin)
          put "/t/#{topic.id}/convert-topic/public.json?category_id=#{category.id}"

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"][0]).to end_with(
            I18n.t("errors.messages.topic_title_already_used", url: existing_topic.url),
          )
        end
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

    it "ignores invalid timing values" do
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

      tu = TopicUser.find_by(user: user, topic: topic)
      expect(tu.last_read_post_number).to eq(post_1.post_number)

      # lets also test timing recovery here
      tu.update!(last_read_post_number: 999)

      post "/topics/timings.json", params: params

      tu = TopicUser.find_by(user: user, topic: topic)
      expect(tu.last_read_post_number).to eq(post_1.post_number)
    end

    it "ignores invalid timing values from staff" do
      sign_in(admin)

      post "/topics/timings.json",
           params: {
             topic_id: topic.id,
             topic_time: 5,
             timings: {
               post_1.post_number => 2,
               whisper.post_number => 2,
               1000 => 100,
             },
           }

      expect(response.status).to eq(200)

      tu = TopicUser.find_by(user: admin, topic: topic)
      expect(tu.last_read_post_number).to eq(whisper.post_number)
    end

    it "does not record timings for a topic the user cannot see" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      private_post = Fabricate(:post, topic: private_topic)

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

    it "records the topic timing" do
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

      post_timing = PostTiming.first

      expect(post_timing.topic).to eq(topic)
      expect(post_timing.user).to eq(user)
      expect(post_timing.msecs).to eq(2)
    end

    it "caps post read time at the max integer value (2^31 - 1)" do
      PostTiming.create!(
        topic_id: post_1.topic.id,
        post_number: post_1.post_number,
        user_id: user.id,
        msecs: 2**31 - 10,
      )
      sign_in(user)

      post "/topics/timings.json",
           params: {
             topic_id: topic.id,
             topic_time: 5,
             timings: {
               post_1.post_number => 100,
             },
           }

      expect(response.status).to eq(200)
      post_timing = PostTiming.first

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

      before do
        topic_timer_group.add(user)
        user.reload
        SiteSetting.topic_timers_allowed_groups = topic_timer_group.id.to_s
        sign_in(user)
      end

      it "allows creating a topic timer" do
        post "/t/#{topic.id}/timer.json", params: { time: "24", status_type: TopicTimer.types[1] }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer.user).to eq(user)
      end

      it "requires delete permissions for destructive timers" do
        post "/t/#{topic.id}/timer.json", params: { time: "24", status_type: "delete" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
        expect(topic.reload.public_topic_timer).to eq(nil)
      end
    end

    context "when time is in the past" do
      it "returns an error" do
        freeze_time
        sign_in(admin)

        post "/t/#{topic.id}/timer.json",
             params: {
               time: 1.day.ago,
               status_type: TopicTimer.types[1],
             }
        expect(response.status).to eq(400)
      end
    end

    context "when logged in as an admin" do
      before do
        freeze_time
        sign_in(admin)
      end

      it "creates a topic status update" do
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
      end

      it "deletes a topic status update" do
        Fabricate(:topic_timer, topic: topic)

        post "/t/#{topic.id}/timer.json", params: { time: nil, status_type: TopicTimer.types[1] }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)

        json = response.parsed_body

        expect(json["execute_at"]).to eq(nil)
        expect(json["duration_minutes"]).to eq(nil)
        expect(json["closed"]).to eq(topic.closed)
      end

      it "creates a topic status update with a duration" do
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
      end

      it "deletes a delete_replies topic status update" do
        Fabricate(:topic_timer, topic: topic, status_type: TopicTimer.types[:delete_replies])

        post "/t/#{topic.id}/timer.json", params: { time: nil, status_type: TopicTimer.types[7] }

        expect(response.status).to eq(200)
        expect(topic.reload.public_topic_timer).to eq(nil)

        json = response.parsed_body

        expect(json["execute_at"]).to eq(nil)
        expect(json["duration"]).to eq(nil)
        expect(json["closed"]).to eq(topic.closed)
      end

      describe "publishing topic to category in the future" do
        it "creates the topic status update" do
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

          json = response.parsed_body

          expect(json["category_id"]).to eq(topic.category_id)
        end
      end

      describe "publishing topic to category without category_id" do
        it "returns an error when setting a timer" do
          post "/t/#{topic.id}/timer.json", params: { time: 24, status_type: "publish_to_category" }

          expect(response.status).to eq(404)
        end

        it "allows removing a timer" do
          topic.set_or_create_timer(
            TopicTimer.types[:publish_to_category],
            24,
            by_user: admin,
            category_id: topic.category_id,
          )

          post "/t/#{topic.id}/timer.json",
               params: {
                 time: nil,
                 status_type: "publish_to_category",
               }

          expect(response.status).to eq(200)
          expect(topic.reload.public_topic_timer).to eq(nil)
        end
      end

      describe "invalid status type" do
        it "returns the invalid-status error" do
          post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "something" }
          expect(response.status).to eq(400)
          expect(response.body).to include("status_type")
        end
      end
    end

    context "when logged in as a TL4 user" do
      before { SiteSetting.enable_category_group_moderation = true }

      it "raises an error if the user can't see the topic" do
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
      end

      it "raises an error when publishing a private message to a category" do
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

      it "allows a category moderator to create a delete timer" do
        user.update!(trust_level: TrustLevel[4])
        Group.user_trust_level_change!(user.id, user.trust_level)
        Fabricate(:category_moderation_group, category: topic.category, group: user.groups.first)

        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "delete" }

        expect(response.status).to eq(200)
      end

      it "raises an error setting a delete timer" do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "delete" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
      end

      it "raises an error setting delete_replies timer" do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)

        post "/t/#{topic.id}/timer.json", params: { time: 10, status_type: "delete_replies" }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
      end

      it "allows category moderators to set delete_replies timer" do
        user.update!(trust_level: TrustLevel[4])
        Group.user_trust_level_change!(user.id, user.trust_level)
        Fabricate(:category_moderation_group, category: topic.category, group: user.groups.first)

        sign_in(user)

        post "/t/#{topic.id}/timer.json",
             params: {
               duration_minutes: 1440,
               status_type: "delete_replies",
             }

        expect(response.status).to eq(200)

        topic_timer = TopicTimer.last
        expect(topic_timer.status_type).to eq(TopicTimer.types[:delete_replies])
      end

      it "raises an error when publishing to a staff-only category" do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)

        staff_category = Fabricate(:category)
        staff_category.set_permissions(staff: :full)
        staff_category.save!

        post "/t/#{topic.id}/timer.json",
             params: {
               time: 24,
               status_type: "publish_to_category",
               category_id: staff_category.id,
             }

        expect(response.status).to eq(403)
        expect(response.parsed_body["error_type"]).to eq("invalid_access")
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
      it "returns a forbidden response" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        expect(response.status).to eq(403)
      end
    end

    context "when logged in as an admin" do
      it "allows admins to set the slow mode interval" do
        sign_in(admin)

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        topic.reload
        expect(response.status).to eq(200)
        expect(topic.slow_mode_seconds).to eq(3600)
      end
    end

    context "when logged in as a regular user" do
      it "does nothing if the user is not TL4" do
        user.update!(trust_level: TrustLevel[3])
        sign_in(user)

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        expect(response.status).to eq(403)
      end

      it "allows TL4 users to set the slow mode interval" do
        user.update!(trust_level: TrustLevel[4])
        sign_in(user)

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600" }

        topic.reload
        expect(response.status).to eq(200)
        expect(topic.slow_mode_seconds).to eq(3600)
      end
    end

    context "with auto-disable slow mode" do
      before { sign_in(admin) }

      let!(:timestamp) { 1.week.from_now.to_formatted_s(:iso8601) }

      it "sets a topic timer to clear the slow mode automatically" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600", enabled_until: timestamp }

        created_timer = TopicTimer.find_by(topic: topic)
        execute_at = created_timer.execute_at.to_formatted_s(:iso8601)

        expect(execute_at).to eq(timestamp)
      end

      it "deletes the topic timer" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600", enabled_until: timestamp }

        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "0", enabled_until: timestamp }

        created_timer = TopicTimer.find_by(topic: topic)

        expect(created_timer).to be_nil
      end

      it "updates the existing timer" do
        put "/t/#{topic.id}/slow_mode.json", params: { seconds: "3600", enabled_until: timestamp }

        updated_timestamp = 1.hour.from_now.to_formatted_s(:iso8601)

        put "/t/#{topic.id}/slow_mode.json",
            params: {
              seconds: "3600",
              enabled_until: updated_timestamp,
            }

        created_timer = TopicTimer.find_by(topic: topic)
        execute_at = created_timer.execute_at.to_formatted_s(:iso8601)

        expect(execute_at).to eq(updated_timestamp)
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

      context "when topic id is not PM" do
        fab!(:user_topic) { Fabricate(:topic, user: user) }

        it "rejects a non-private-message topic" do
          user.update!(trust_level: TrustLevel[2])

          post "/t/#{user_topic.id}/invite.json", params: { email: "someguy@email.com" }

          expect(response.status).to eq(422)
        end
      end

      context "when topic id is invalid" do
        it "returns a not-found response" do
          id = topic.id
          topic.destroy!
          post "/t/#{id}/invite.json", params: { email: user.email }

          expect(response.status).to eq(404)
        end
      end

      it "requires an email parameter" do
        post "/t/#{topic.id}/invite.json"
        expect(response.status).to eq(422)
      end

      context "when PM has reached maximum allowed numbers of recipients" do
        fab!(:pm) { Fabricate(:private_message_topic, user: user) }

        fab!(:moderator_pm) { Fabricate(:private_message_topic, user: moderator) }

        before { SiteSetting.max_allowed_message_recipients = 2 }

        it "doesn't allow normal users to invite" do
          post "/t/#{pm.id}/invite.json", params: { user: user_2.username }
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to contain_exactly(
            I18n.t(
              "pm_reached_recipients_limit",
              recipients_limit: SiteSetting.max_allowed_message_recipients,
            ),
          )
        end

        it "allows staff to bypass limits" do
          sign_in(moderator)
          post "/t/#{moderator_pm.id}/invite.json", params: { user: user_2.username }
          expect(response.status).to eq(200)
          expect(moderator_pm.reload.topic_allowed_users.count).to eq(3)
        end
      end

      it "does not disclose an existing user from an email invite" do
        pm = Fabricate(:private_message_topic, user: user)

        post "/t/#{pm.id}/invite.json", params: { email: user_2.email }

        expect(response.status).to eq(422)
        expect(response.parsed_body["failed"]).to eq("FAILED")
        expect(pm.reload.topic_allowed_users.pluck(:user_id)).not_to include(user_2.id)
      end

      it "does not disclose an existing user from a form-encoded array email invite" do
        pm = Fabricate(:private_message_topic, user: user)

        post "/t/#{pm.id}/invite.json", params: { email: [user_2.email, "@"] }

        expect(response.status).to eq(422)
        expect(response.parsed_body["failed"]).to eq("FAILED")
        expect(response.body).not_to include(user_2.username)
        expect(pm.reload.topic_allowed_users.pluck(:user_id)).not_to include(user_2.id)
      end

      it "returns generic success without side effects when an authorized email invite matches an existing user" do
        sign_in(admin)
        pm = Fabricate(:private_message_topic, user: admin)
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

      context "when user does not have permission to invite to the topic" do
        fab!(:topic) { pm }

        it "forbids a user without invitation permission" do
          post "/t/#{topic.id}/invite.json", params: { user: user.username }

          expect(response.status).to eq(403)
        end
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

    context "as an anon user" do
      it "forbids the invitation" do
        invite_group(pm, 403)
      end
    end

    context "as a normal user" do
      before { sign_in(user) }

      context "when user does not have permission to view the topic" do
        it "forbids the invitation" do
          invite_group(pm, 403)
        end
      end

      context "when user has permission to view the topic" do
        before { pm.allowed_users << user }

        it "allows the user to invite a group to the topic" do
          invite_group(pm, 200)
          expect(pm.allowed_groups.first.id).to eq(admins.id)
        end
      end
    end

    context "as an admin user" do
      before { sign_in(admin) }

      it "disallows inviting a group to a topic" do
        invite_group(topic, 422)
      end

      it "allows inviting a group to a PM" do
        invite_group(pm, 200)
        expect(pm.allowed_groups.first.id).to eq(admins.id)
      end

      it "sends a notification to the group" do
        user = Fabricate(:user)
        Fabricate(:post, topic: pm)
        admins.add(user)
        admins
          .group_users
          .find_by(user_id: user.id)
          .update!(notification_level: NotificationLevels.all[:watching])

        Notification.delete_all
        Jobs.run_immediately!
        post "/t/#{pm.id}/invite-group.json", params: { group: "admins" }

        expect(response.status).to eq(200)
        expect(Notification.count).to be > 0
      end

      it "allows disabling notifications for that invite" do
        user = Fabricate(:user)
        Fabricate(:post, topic: pm)
        admins.add(user)
        admins
          .group_users
          .find_by(user_id: user.id)
          .update!(notification_level: NotificationLevels.all[:watching])

        Notification.delete_all
        Jobs.run_immediately!
        post "/t/#{pm.id}/invite-group.json", params: { group: "admins", should_notify: false }

        expect(response.status).to eq(200)
        expect(Notification.count).to eq(0)
      end
    end

    context "when PM has reached maximum allowed numbers of recipients" do
      fab!(:group) { Fabricate(:group, messageable_level: 99) }
      fab!(:pm) { Fabricate(:private_message_topic, user: user) }

      fab!(:moderator_pm) { Fabricate(:private_message_topic, user: moderator) }

      before { SiteSetting.max_allowed_message_recipients = 2 }

      it "doesn't allow normal users to invite" do
        post "/t/#{pm.id}/invite-group.json", params: { group: group.name }
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to contain_exactly(
          I18n.t(
            "pm_reached_recipients_limit",
            recipients_limit: SiteSetting.max_allowed_message_recipients,
          ),
        )
      end

      it "allows staff to bypass limits" do
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
    before { SiteSetting.shared_drafts_category = shared_drafts_category.id }

    describe "#update_shared_draft" do
      fab!(:other_cat, :category)
      fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }

      context "when anonymous" do
        it "doesn't allow staff to update the shared draft" do
          put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
          expect(response.code.to_i).to eq(403)
        end
      end

      context "as a moderator" do
        before { sign_in(moderator) }

        context "with a shared draft" do
          fab!(:shared_draft) { Fabricate(:shared_draft, topic: topic, category: category) }
          it "allows staff to update the category id" do
            put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
            expect(response.status).to eq(200)
            topic.reload
            expect(topic.shared_draft.category_id).to eq(other_cat.id)
          end
        end

        context "without a shared draft" do
          it "allows staff to update the category id" do
            put "/t/#{topic.id}/shared-draft.json", params: { category_id: other_cat.id }
            expect(response.status).to eq(200)
            topic.reload
            expect(topic.shared_draft.category_id).to eq(other_cat.id)
          end
        end
      end
    end

    describe "#publish" do
      fab!(:topic) { Fabricate(:topic, category: shared_drafts_category, visible: false) }
      fab!(:post) { Fabricate(:post, user: post_author1, topic: topic) }

      it "fails for anonymous users" do
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      it "fails as a regular user" do
        sign_in(user)
        put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
        expect(response.status).to eq(403)
      end

      context "as staff" do
        before { sign_in(moderator) }

        it "publishes the topic" do
          put "/t/#{topic.id}/publish.json", params: { destination_category_id: category.id }
          expect(response.status).to eq(200)
          json = response.parsed_body["basic_topic"]

          result = Topic.find(json["id"])
          expect(result.category_id).to eq(category.id)
          expect(result.visible).to eq(true)
        end

        it "fails if the destination category is the shared drafts category" do
          put "/t/#{topic.id}/publish.json",
              params: {
                destination_category_id: shared_drafts_category.id,
              }
          expect(response.status).to eq(400)
        end
      end
    end
  end

  describe "crawler" do
    context "when not a crawler" do
      it "renders with the application layout" do
        get topic.relative_url

        body = response.body

        expect(body).to have_tag(:script, with: { "data-discourse-entrypoint" => "discourse" })
        expect(body).to have_tag(:meta, with: { name: "fragment" })
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

      it "does not include the tags in the print view for participants who cannot tag PMs" do
        sign_in(participant)

        get "#{pm.relative_url}/print"

        expect(response.status).to eq(200)
        expect(response.body).not_to include(pm_tag.name)
      end

      it "includes the tags in the print view for participants who can tag PMs" do
        SiteSetting.pm_tags_allowed_for_groups = Group::AUTO_GROUPS[:trust_level_0]
        sign_in(participant)

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
          20,
          :post,
          user: post_author2,
          topic: topic,
          created_at: page1_time,
          updated_at: page1_time,
        )
      end

      fab!(:page_2_posts) do
        Fabricate.times(
          20,
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

      let!(:bot_user_agent) do
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

        expect(body).to include("id='post_21'")
        expect(body).to include("id='post_22'")

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
        get "#{topic.relative_url}/24"
        expect(response.body).to have_tag("#post_24")
        expect(response.body).not_to have_tag("#post_23")
        expect(response.body).not_to have_tag("#post_25")
        expect(response.body).not_to have_tag("a", with: { rel: "next" })
        expect(response.body).not_to have_tag("a", with: { rel: "prev" })
        expect(response.body).to have_tag(
          "a",
          text: I18n.t("show_post_in_topic"),
          with: {
            href: "#{topic.relative_url}?page=2#post_24",
          },
        )
      end

      it "includes top-level author metadata when the view does not include the OP naturally" do
        get "#{topic.relative_url}/2"
        expect(body).to have_tag(
          "[itemtype='http://schema.org/DiscussionForumPosting'] > [itemprop='author']",
        )

        get "#{topic.relative_url}/27"
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

      context "with canonical_url" do
        fab!(:topic_embed) { Fabricate(:topic_embed, embed_url: "https://markvanlan.com") }

        it "set to topic.url when embed_set_canonical_url is false" do
          get topic_embed.topic.url, env: { "HTTP_USER_AGENT" => bot_user_agent }
          expect(response.body).to include('<link rel="canonical" href="' + topic_embed.topic.url)
        end

        it "set to topic_embed.embed_url when embed_set_canonical_url is true" do
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

        before do
          SiteSetting.content_localization_enabled = true
          SiteSetting.allow_user_locale = true
          SiteSetting.set_locale_from_param = true

          topic.update!(category: subcategory, tags: [tag], locale: "en")
          topic.first_post.update(locale: "en")
          # randomly create localizations for an untested locale
          topic
            .posts
            .sample(3)
            .each do |post|
              post.update!(locale: "en")
              Fabricate(:post_localization, post:, locale: "de")
            end
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

          it "localizes (english) topic for crawler to (portuguese) default locale when localization exists" do
            SiteSetting.default_locale = "pt"

            get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

            expect(response.body).to include(pt_topic.title)
            expect(response.body).to include(pt_category.name)
            expect(response.body).to include(pt_subcategory.name)
            expect(response.body).to include(pt_first_post.cooked)
          end

          it "leaves topic as-is if no localization" do
            SiteSetting.default_locale = "es"

            get topic.relative_url, env: { "HTTP_USER_AGENT" => bot_user_agent }

            expect(response.body).to include(topic.title)
            expect(response.body).to include(category.name)
            expect(response.body).to include(subcategory.name)
            expect(response.body).to include(topic.first_post.cooked)
          end
        end

        describe "when tl param is present ?tl=ja" do
          fab!(:ja_topic) { Fabricate(:topic_localization, topic:, locale: "ja") }
          fab!(:ja_category) { Fabricate(:category_localization, category:, locale: "ja") }
          fab!(:ja_subcategory) do
            Fabricate(:category_localization, category: subcategory, locale: "ja")
          end

          it "localizes topic for crawler" do
            get topic.relative_url,
                env: {
                  "HTTP_USER_AGENT" => bot_user_agent,
                },
                params: {
                  tl: "ja",
                }

            expect(response.body).to include(ja_topic.title)
            # breadcrumbs
            expect(response.body).to include(ja_category.name)
            expect(response.body).to include(ja_subcategory.name)
          end

          it "does not persist localized fancy_title to the database when topic fancy_title is null" do
            topic.update_column(:fancy_title, nil)

            get topic.relative_url,
                env: {
                  "HTTP_USER_AGENT" => bot_user_agent,
                },
                params: {
                  tl: "ja",
                }

            expect(response.status).to eq(200)

            db_fancy_title = Topic.where(id: topic.id).pick(:fancy_title)
            localized_fancy_title = Topic.fancy_title(ja_topic.title)
            expect(db_fancy_title).not_to eq(localized_fancy_title)
          end
        end

        it "does not have N+1s when loading localizations" do
          Fabricate(:topic_localization, topic:, locale: "ja")
          topic
            .posts
            .where("post_number < 4")
            .each { |post| Fabricate(:post_localization, post:, locale: "ja") }

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

          Fabricate(:post_localization, post: topic.posts.find_by_post_number(4), locale: "ja")

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

          expect(new_sql_queries).to eq(initial_sql_queries)
        end
      end
    end
  end

  describe "#reset_bump_date" do
    context "with errors" do
      it "needs you to be logged in" do
        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(403)
      end

      [:user].each do |user|
        it "denies access for #{user}" do
          sign_in(Fabricate(user))
          put "/t/#{topic.id}/reset-bump-date.json"
          expect(response.status).to eq(403)
        end
      end

      it "returns an error for a missing topic" do
        max_id = Topic.maximum(:id)
        sign_in(admin)
        put "/t/#{max_id + 1}/reset-bump-date.json"
        expect(response.status).to eq(404)
      end

      it "denies access for TL4 user on a topic in a restricted category" do
        restricted_topic = Fabricate(:topic, category: staff_category)
        sign_in(trust_level_4)
        put "/t/#{restricted_topic.id}/reset-bump-date.json"
        expect(response.status).to eq(403)
      end
    end

    %i[admin moderator trust_level_4].each do |user|
      it "resets bumped_at as #{user}" do
        sign_in(public_send(user))
        topic.update!(bumped_at: 1.hour.ago)
        timestamp = 1.day.ago
        Fabricate(:post, user: post_author1, topic: topic, created_at: timestamp)

        put "/t/#{topic.id}/reset-bump-date.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to eq_time(timestamp)
      end
    end

    context "with a post_id parameter" do
      before { sign_in(admin) }

      it "resets bump correctly" do
        post1 = Fabricate(:post, user: post_author1, topic: topic, created_at: 2.days.ago)
        _post2 = Fabricate(:post, user: post_author1, topic: topic, created_at: 1.day.ago)

        put "/t/#{topic.id}/reset-bump-date/#{post1.id}.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to eq_time(post1.created_at)
      end

      it "does not raise an error for an inexistent post" do
        id = (SecureRandom.random_number * 100_000_000).to_i
        original_bumped_at = topic.bumped_at

        put "/t/#{topic.id}/reset-bump-date/#{id}.json"
        expect(response.status).to eq(200)
        expect(topic.reload.bumped_at).to eq_time(original_bumped_at)
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

    it "returns the right response when inbox param is missing" do
      put "/topics/pm-reset-new.json"

      expect(response.status).to eq(400)
    end

    it "returns the right response when trying to reset new private messages of an invalid group" do
      put "/topics/pm-reset-new.json", params: { inbox: "group", group_name: "randomgroup" }

      expect(response.status).to eq(404)
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

    it "returns the right response is topic_ids params is not valid" do
      put "/topics/pm-reset-new.json", params: { topic_ids: "1" }

      expect(response.status).to eq(400)
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

  describe "#archive_message" do
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

    it "returns not found for a user who is not a participant of the message" do
      sign_in(user_2)

      put "/t/#{group_message.id}/archive-message.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
    end
  end

  describe "#move_to_inbox" do
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

    it "returns not found for a user who is not a participant of the message" do
      sign_in(user_2)

      put "/t/#{group_message.id}/move-to-inbox.json"
      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
    end
  end

  describe "#set_notifications" do
    let(:watching) { NotificationLevels.topic_levels[:watching] }

    it "rejects `username` param for session requests" do
      sign_in(user)
      post "/t/#{topic.id}/notifications.json",
           params: {
             username: user_2.username,
             notification_level: watching,
           }

      expect(response.status).to eq(403)
      expect(TopicUser.find_by(user: user, topic: topic)).to be_blank
      expect(TopicUser.find_by(user: user_2, topic: topic)).to be_blank
    end

    describe "via API" do
      it "admin can target another user with `username` param" do
        api_key = Fabricate(:api_key, user: admin).key
        post "/t/#{topic.id}/notifications",
             params: {
               username: user.username,
               notification_level: watching,
             },
             headers: {
               HTTP_API_KEY: api_key,
               HTTP_API_USERNAME: admin.username,
             }

        expect(TopicUser.find_by(user: user, topic: topic).notification_level).to eq(watching)
      end

      it "admin acts on self when `username` param is absent" do
        api_key = Fabricate(:api_key, user: admin).key
        post "/t/#{topic.id}/notifications",
             params: {
               notification_level: watching,
             },
             headers: {
               HTTP_API_KEY: api_key,
               HTTP_API_USERNAME: admin.username,
             }

        expect(TopicUser.find_by(user: admin, topic: topic).notification_level).to eq(watching)
      end

      it "non-admin gets 403 when passing `username` to target another user" do
        api_key = Fabricate(:api_key, user: user).key
        post "/t/#{topic.id}/notifications",
             params: {
               username: user_2.username,
               notification_level: watching,
             },
             headers: {
               HTTP_API_KEY: api_key,
               HTTP_API_USERNAME: user.username,
             }

        expect(response.status).to eq(403)
        expect(TopicUser.find_by(user: user, topic: topic)).to be_blank
        expect(TopicUser.find_by(user: user_2, topic: topic)).to be_blank
      end

      it "non-admin acts on self when `username` param is absent" do
        api_key = Fabricate(:api_key, user: user).key
        post "/t/#{topic.id}/notifications",
             params: {
               notification_level: watching,
             },
             headers: {
               HTTP_API_KEY: api_key,
               HTTP_API_USERNAME: user.username,
             }

        expect(TopicUser.find_by(user: user, topic: topic).notification_level).to eq(watching)
      end
    end

    it "returns not found when a regular user sets notifications on a private message they cannot see" do
      sign_in(user)

      post "/t/#{pm.id}/notifications.json",
           params: {
             notification_level: NotificationLevels.topic_levels[:watching],
           }

      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
      expect(TopicUser.find_by(user: user, topic: pm)).to be_blank
    end

    it "returns not found when a regular user sets notifications on a topic in a restricted category" do
      restricted_topic = Fabricate(:topic, category: staff_category)
      sign_in(user)

      post "/t/#{restricted_topic.id}/notifications.json",
           params: {
             notification_level: NotificationLevels.topic_levels[:watching],
           }

      expect(response.status).to eq(404)
      expect(response.parsed_body["error_type"]).to eq("not_found")
      expect(TopicUser.find_by(user: user, topic: restricted_topic)).to be_blank
    end
  end

  describe ".defer_topic_view" do
    fab!(:topic)
    fab!(:user)

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
    fab!(:topic)

    before { SiteSetting.embed_full_app = true }

    it "keeps X-Frame-Options when embed_mode param is missing" do
      get("/t/#{topic.slug}/#{topic.id}")
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end

    it "keeps X-Frame-Options when embed_mode is present but referer is invalid" do
      get("/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" })
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end

    it "strips X-Frame-Options when embed_mode is present and referer matches embeddable host" do
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
    end

    it "strips X-Frame-Options when embed_mode is present and embed_any_origin is enabled" do
      SiteSetting.embed_any_origin = true
      get("/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" })
      expect(response.headers).not_to include("X-Frame-Options")
    end

    it "keeps X-Frame-Options when embed_full_app is disabled" do
      SiteSetting.embed_full_app = false
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
      expect(response.headers["X-Frame-Options"]).to eq("SAMEORIGIN")
    end

    it "applies class_name to the html element when embed_mode is allowed" do
      SiteSetting.embed_any_origin = true
      get("/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true", class_name: "lee-af" })
      expect(response.body).to match(/<html[^>]*\bclass="[^"]*\blee-af\b/)
    end

    it "ignores class_name when embed_mode is not allowed" do
      get("/t/#{topic.slug}/#{topic.id}", params: { class_name: "lee-af" })
      expect(response.body).not_to match(/<html[^>]*\blee-af\b/)
    end

    it "ignores class_name with invalid characters" do
      SiteSetting.embed_any_origin = true
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
    fab!(:topic)

    before do
      SiteSetting.embed_full_app = true
      SiteSetting.gtm_container_id = "GTM-ABCDEF"
      SiteSetting.adobe_analytics_tags_url = "https://assets.adobedtm.com/launch-EN.min.js"
    end

    def parsed_body
      Nokogiri::HTML5.fragment(response.body)
    end

    it "renders analytics tags by default" do
      get "/t/#{topic.slug}/#{topic.id}"
      expect(parsed_body.css("#data-google-tag-manager")).to be_present
      expect(
        parsed_body.css("script[src='https://assets.adobedtm.com/launch-EN.min.js']"),
      ).to be_present
    end

    it "skips analytics tags when loaded in embed mode" do
      get "/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" }
      expect(parsed_body.css("#data-google-tag-manager")).to be_empty
      expect(
        parsed_body.css("script[src='https://assets.adobedtm.com/launch-EN.min.js']"),
      ).to be_empty
    end

    it "still renders analytics tags in embed mode when suppression setting is disabled" do
      SiteSetting.suppress_third_party_analytics_in_embed = false
      get "/t/#{topic.slug}/#{topic.id}", params: { embed_mode: "true" }
      expect(parsed_body.css("#data-google-tag-manager")).to be_present
      expect(
        parsed_body.css("script[src='https://assets.adobedtm.com/launch-EN.min.js']"),
      ).to be_present
    end
  end
end
