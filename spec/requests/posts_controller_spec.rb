# frozen_string_literal: true

RSpec.shared_examples "finding and showing post" do
  let!(:post) { post_by_user }

  it "ensures the user can't see the post" do
    topic = post.topic
    topic.convert_to_private_message(Discourse.system_user)
    topic.remove_allowed_user(Discourse.system_user, user.username)
    get url
    expect(response).to be_forbidden
  end

  it "succeeds" do
    get url
    expect(response.status).to eq(200)
  end

  it "returns 404 when post's topic is deleted" do
    post.topic.destroy!
    get url
    expect(response.status).to eq(404)
  end

  context "with deleted post" do
    before { post.trash!(user) }

    it "can't find deleted posts as an anonymous user" do
      get url
      expect(response.status).to eq(404)
    end

    it "can't find deleted posts as a regular user" do
      sign_in(user)
      get url
      expect(response.status).to eq(404)
    end

    it "can find posts as a moderator" do
      sign_in(moderator)
      get url
      expect(response.status).to eq(200)
    end

    it "can find posts as a admin" do
      sign_in(admin)
      get url
      expect(response.status).to eq(200)
    end

    context "with category group moderator" do
      fab!(:group_user)
      let(:user_gm) { group_user.user }
      let(:group) { group_user.group }

      before do
        SiteSetting.enable_category_group_moderation = true
        sign_in(user_gm)
      end

      it "can find posts in the allowed category" do
        post.topic.category.update!(topic_id: topic.id)
        Fabricate(:category_moderation_group, category: post.topic.category, group:)
        get url
        expect(response.status).to eq(200)
      end

      it "can't find posts outside of the allowed category" do
        get url
        expect(response.status).to eq(404)
      end
    end
  end
end

RSpec.shared_examples "action requires login" do |method, url, params = {}|
  it "raises an exception when not logged in" do
    self.public_send(method, url, **params)
    expect(response.status).to eq(403)
  end
end

RSpec.describe PostsController do
  fab!(:admin)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:user_trust_level_0) { Fabricate(:trust_level_0) }
  fab!(:user_trust_level_1) { Fabricate(:trust_level_1) }
  fab!(:category)
  fab!(:topic)
  fab!(:post_by_user) { Fabricate(:post, user: user) }
  let(:public_post) { Fabricate(:post, user: user, topic: topic) }
  let(:topicless_post) { Fabricate(:post, user: user, raw: "<p>Car 54, where are you?</p>") }

  let(:private_topic) { Fabricate(:topic, archetype: Archetype.private_message, category_id: nil) }
  let(:private_post) { Fabricate(:post, user: user, topic: private_topic) }

  describe "#show" do
    include_examples "finding and showing post" do
      let(:url) { "/posts/#{post.id}.json" }
    end

    it "gets all the expected fields" do
      # non fabricated test
      new_post = create_post

      get "/posts/#{new_post.id}.json"
      parsed = response.parsed_body

      expect(parsed["topic_slug"]).to eq(new_post.topic.slug)
      expect(parsed["moderator"]).to eq(false)
      expect(parsed["username"]).to eq(new_post.user.username)
      expect(parsed["cooked"]).to eq(new_post.cooked)
    end
  end

  describe "#by_number" do
    include_examples "finding and showing post" do
      let(:url) { "/posts/by_number/#{post.topic_id}/#{post.post_number}.json" }
    end
  end

  describe "#by_date" do
    include_examples "finding and showing post" do
      let(:url) { "/posts/by-date/#{post.topic_id}/#{post.created_at.strftime("%Y-%m-%d")}.json" }
    end

    it "returns the expected post" do
      first_post = Fabricate(:post, created_at: 10.days.ago)
      second_post = Fabricate(:post, topic: first_post.topic, created_at: 4.days.ago)
      _third_post = Fabricate(:post, topic: first_post.topic, created_at: 3.days.ago)

      get "/posts/by-date/#{second_post.topic_id}/#{(second_post.created_at - 2.days).strftime("%Y-%m-%d")}.json"
      json = response.parsed_body

      expect(response.status).to eq(200)
      expect(json["id"]).to eq(second_post.id)
    end

    it "returns no post if date is > at last created post" do
      get "/posts/by-date/#{post.topic_id}/2245-11-11.json"
      _json = response.parsed_body
      expect(response.status).to eq(404)
    end
  end

  describe "#reply_history" do
    include_examples "finding and showing post" do
      let(:url) { "/posts/#{post.id}/reply-history.json" }
    end

    it "returns the replies with allowlisted user custom fields" do
      parent = Fabricate(:post)
      child = Fabricate(:post, topic: parent.topic, reply_to_post_number: parent.post_number)

      parent.user.upsert_custom_fields(hello: "world", hidden: "dontshow")
      SiteSetting.public_user_custom_fields = "hello"

      get "/posts/#{child.id}/reply-history.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json[0]["id"]).to eq(parent.id)
      expect(json[0]["user_custom_fields"]["hello"]).to eq("world")
      expect(json[0]["user_custom_fields"]["hidden"]).to be_blank
    end
  end

  describe "#reply_ids" do
    include_examples "finding and showing post" do
      let(:url) { "/posts/#{post.id}/reply-ids.json" }
    end

    it "returns ids of post's replies" do
      post = Fabricate(:post)
      reply1 = Fabricate(:post, topic: post.topic, reply_to_post_number: post.post_number)
      reply2 = Fabricate(:post, topic: post.topic, reply_to_post_number: post.post_number)
      PostReply.create(post_id: post.id, reply_post_id: reply1.id)
      PostReply.create(post_id: post.id, reply_post_id: reply2.id)

      get "/posts/#{post.id}/reply-ids.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body).to eq(
        [{ "id" => reply1.id, "level" => 1 }, { "id" => reply2.id, "level" => 1 }],
      )
    end
  end

  describe "#replies" do
    include_examples "finding and showing post" do
      let(:url) { "/posts/#{post.id}/replies.json" }
    end

    it "asks post for replies" do
      parent = Fabricate(:post)
      child = Fabricate(:post, topic: parent.topic, reply_to_post_number: parent.post_number)
      PostReply.create!(post: parent, reply: child)

      child.user.upsert_custom_fields(hello: "world", hidden: "dontshow")
      SiteSetting.public_user_custom_fields = "hello"

      get "/posts/#{parent.id}/replies.json"
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json[0]["id"]).to eq(child.id)
      expect(json[0]["user_custom_fields"]["hello"]).to eq("world")
      expect(json[0]["user_custom_fields"]["hidden"]).to be_blank
    end

    it "supports pagination" do
      parent = Fabricate(:post)
      30.times do
        reply = Fabricate(:post, topic: parent.topic, reply_to_post_number: parent.post_number)
        PostReply.create!(post: parent, reply:)
      end

      get "/posts/#{parent.id}/replies.json", params: { after: parent.post_number }
      expect(response.status).to eq(200)
      replies = response.parsed_body
      expect(replies.size).to eq(20)

      after = replies.last["post_number"]

      get "/posts/#{parent.id}/replies.json", params: { after: }
      expect(response.status).to eq(200)
      replies = response.parsed_body
      expect(replies.size).to eq(10)
      expect(replies[0][:post_number]).to eq(after + 1)

      get "/posts/#{parent.id}/replies.json", params: { after: 999_999 }
      expect(response.status).to eq(200)
      expect(response.parsed_body.size).to eq(0)
    end
  end

  describe "#destroy" do
    include_examples "action requires login", :delete, "/posts/123.json"

    describe "when logged in" do
      let(:topic) { Fabricate(:topic) }

      it "raises an error when the user doesn't have permission to see the post" do
        pm = Fabricate(:private_message_topic)
        post = Fabricate(:post, topic: pm, post_number: 3)

        sign_in(user)

        delete "/posts/#{post.id}.json"
        expect(response).to be_forbidden
      end

      it "raises an error when the self deletions are disabled" do
        SiteSetting.max_post_deletions_per_day = 0
        post = Fabricate(:post, user: user, topic: topic, post_number: 3)
        sign_in(user)

        delete "/posts/#{post.id}.json"
        expect(response).to be_forbidden
      end

      it "uses a PostDestroyer" do
        post = Fabricate(:post, topic_id: topic.id, post_number: 3)
        sign_in(moderator)

        destroyer = mock
        PostDestroyer.expects(:new).returns(destroyer)
        destroyer.expects(:destroy)

        delete "/posts/#{post.id}.json"
      end

      context "with permanently destroy" do
        let!(:post) { Fabricate(:post, topic_id: topic.id, post_number: 3) }

        before { SiteSetting.can_permanently_delete = true }

        it "does not work for a post that was not deleted yet" do
          sign_in(admin)

          delete "/posts/#{post.id}.json", params: { force_destroy: true }
          expect(response.status).to eq(403)
        end

        it "needs some time to pass to permanently delete a topic" do
          sign_in(admin)

          delete "/posts/#{post.id}.json"
          expect(response.status).to eq(200)
          expect(post.reload.deleted_by_id).to eq(admin.id)

          delete "/posts/#{post.id}.json", params: { force_destroy: true }
          expect(response.status).to eq(403)

          post.update!(deleted_at: 10.minutes.ago)

          delete "/posts/#{post.id}.json", params: { force_destroy: true }
          expect(response.status).to eq(200)
          expect { post.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it "needs two users to permanently delete a topic" do
          sign_in(admin)

          delete "/posts/#{post.id}.json"
          expect(response.status).to eq(200)
          expect(post.reload.deleted_by_id).to eq(admin.id)

          sign_in(Fabricate(:admin))

          delete "/posts/#{post.id}.json", params: { force_destroy: true }
          expect(response.status).to eq(200)
          expect { post.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end

        it "moderators cannot permanently delete topics" do
          sign_in(admin)

          delete "/posts/#{post.id}.json"
          expect(response.status).to eq(200)
          expect(post.reload.deleted_by_id).to eq(admin.id)

          sign_in(moderator)

          delete "/posts/#{post.id}.json", params: { force_destroy: true }
          expect(response.status).to eq(403)
        end

        it "creates a log and clean up previously recorded sensitive information" do
          sign_in(admin)

          delete "/posts/#{post.id}.json"
          expect(response.status).to eq(200)
          expect(post.reload.deleted_by_id).to eq(admin.id)

          post.update!(deleted_at: 10.minutes.ago)

          delete "/posts/#{post.id}.json", params: { force_destroy: true }
          expect(response.status).to eq(200)

          expect(UserHistory.last).to have_attributes(
            action: UserHistory.actions[:delete_post_permanently],
            acting_user_id: admin.id,
          )

          expect(UserHistory.where(post_id: post.id, details: "(permanently deleted)").count).to eq(
            2,
          )
        end
      end
    end
  end

  describe "#destroy_many" do
    include_examples "action requires login",
                     :delete,
                     "/posts/destroy_many.json",
                     params: {
                       post_ids: [123, 345],
                     }

    describe "when logged in" do
      fab!(:poster) { Fabricate(:moderator) }
      fab!(:post1) { Fabricate(:post, user: poster, post_number: 2) }
      fab!(:post2) do
        Fabricate(
          :post,
          topic: post1.topic,
          user: poster,
          post_number: 3,
          reply_to_post_number: post1.post_number,
        )
      end

      it "raises invalid parameters no post_ids" do
        sign_in(poster)
        delete "/posts/destroy_many.json"
        expect(response.status).to eq(400)
        expect(response.message.downcase).to eq("bad request")
      end

      it "raises invalid parameters with missing ids" do
        sign_in(poster)
        delete "/posts/destroy_many.json", params: { post_ids: [12_345] }
        expect(response.status).to eq(400)
      end

      it "raises an error when the user doesn't have permission to delete the posts" do
        sign_in(user)
        delete "/posts/destroy_many.json", params: { post_ids: [post1.id, post2.id] }
        expect(response).to be_forbidden
      end

      it "deletes the post" do
        sign_in(poster)
        PostDestroyer.any_instance.expects(:destroy).twice
        delete "/posts/destroy_many.json", params: { post_ids: [post1.id, post2.id] }
        expect(response.status).to eq(200)
      end

      it "updates the highest read data for the forum" do
        sign_in(poster)
        Topic.expects(:reset_highest).twice
        delete "/posts/destroy_many.json", params: { post_ids: [post1.id, post2.id] }
      end

      describe "can delete replies" do
        before { PostReply.create(post_id: post1.id, reply_post_id: post2.id) }

        it "deletes the post and the reply to it" do
          sign_in(poster)
          PostDestroyer.any_instance.expects(:destroy).twice
          delete "/posts/destroy_many.json",
                 params: {
                   post_ids: [post1.id],
                   reply_post_ids: [post1.id],
                 }
        end
      end

      context "when deleting flagged posts" do
        before do
          sign_in(moderator)
          PostActionCreator.off_topic(moderator, post1)
          PostActionCreator.off_topic(moderator, post2)
          Jobs::SendSystemMessage.clear
        end

        it "defers the child posts by default" do
          expect(ReviewableFlaggedPost.pending.count).to eq(2)
          delete "/posts/destroy_many.json", params: { post_ids: [post1.id, post2.id] }
          expect(Jobs::SendSystemMessage.jobs.size).to eq(1)
          expect(ReviewableFlaggedPost.pending.count).to eq(0)
        end

        it "can defer all posts based on `agree_with_first_reply_flag` param" do
          expect(ReviewableFlaggedPost.pending.count).to eq(2)
          delete "/posts/destroy_many.json",
                 params: {
                   post_ids: [post1.id, post2.id],
                   agree_with_first_reply_flag: false,
                 }
          PostActionCreator.off_topic(moderator, post1)
          PostActionCreator.off_topic(moderator, post2)
          Jobs::SendSystemMessage.clear
        end
      end
    end
  end

  describe "#recover" do
    include_examples "action requires login", :put, "/posts/123/recover.json"

    describe "when logged in" do
      it "raises an error when the user doesn't have permission to see the post" do
        post = Fabricate(:post, topic: Fabricate(:private_message_topic), post_number: 3)
        sign_in(user)

        put "/posts/#{post.id}/recover.json"
        expect(response).to be_forbidden
      end

      it "raises an error when self deletion/recovery is disabled" do
        SiteSetting.max_post_deletions_per_day = 0
        post = Fabricate(:post, user: user, topic: topic, post_number: 3)
        sign_in(user)

        put "/posts/#{post.id}/recover.json"
        expect(response).to be_forbidden
      end

      it "recovers a post correctly" do
        topic_id = create_post.topic_id
        post = create_post(topic_id: topic_id)
        sign_in(user)

        PostDestroyer.new(user, post).destroy
        put "/posts/#{post.id}/recover.json"
        post.reload
        expect(post.trashed?).to be_falsey
      end
    end
  end

  describe "#update" do
    include_examples "action requires login", :put, "/posts/2.json"

    let!(:post) { post_by_user }
    let(:update_params) do
      {
        post: {
          raw: "edited body",
          edit_reason: "typo",
        },
        image_sizes: {
          "http://image.com/image.jpg" => {
            "width" => 123,
            "height" => 456,
          },
        },
      }
    end

    describe "when logged in as a regular user" do
      before { sign_in(user) }

      it "does not allow TL0 or TL1 to update when edit time limit expired" do
        SiteSetting.post_edit_time_limit = 5
        SiteSetting.tl2_post_edit_time_limit = 30

        post = Fabricate(:post, created_at: 10.minutes.ago, user: user)

        user.update_columns(trust_level: 1)

        put "/posts/#{post.id}.json", params: update_params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("too_late_to_edit"))
      end

      it "does not allow TL2 to update when edit time limit expired" do
        SiteSetting.post_edit_time_limit = 12
        SiteSetting.tl2_post_edit_time_limit = 8

        user.update_columns(trust_level: 2)

        post = Fabricate(:post, created_at: 10.minutes.ago, user: user)

        put "/posts/#{post.id}.json", params: update_params

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("too_late_to_edit"))
      end

      it "passes the image sizes through" do
        Post.any_instance.expects(:image_sizes=)
        put "/posts/#{post.id}.json", params: update_params
      end

      it "passes the edit reason through" do
        put "/posts/#{post.id}.json", params: update_params
        expect(response.status).to eq(200)
        post.reload
        expect(post.edit_reason).to eq("typo")
        expect(post.raw).to eq("edited body")
      end

      it "checks for an edit conflict" do
        update_params[:post][:raw_old] = "old body"
        put "/posts/#{post.id}.json", params: update_params

        expect(response.status).to eq(409)
      end

      it "raises an error when the post parameter is missing" do
        update_params.delete(:post)
        put "/posts/#{post.id}.json", params: update_params
        expect(response.status).to eq(400)
        expect(response.message.downcase).to eq("bad request")
      end

      it "raises an error when the user doesn't have permission to see the post" do
        post = Fabricate(:private_message_post, post_number: 3)
        put "/posts/#{post.id}.json", params: update_params
        expect(response).to be_forbidden
      end

      it "updates post's raw attribute" do
        put "/posts/#{post.id}.json", params: { post: { raw: "edited body   " } }

        expect(response.status).to eq(200)
        expect(response.parsed_body["post"]["raw"]).to eq("edited body")
        expect(post.reload.raw).to eq("edited body")
      end

      it "extracts links from the new body" do
        param = update_params
        param[:post][:raw] = "I just visited this https://google.com so many cool links"

        put "/posts/#{post.id}.json", params: param

        expect(response.status).to eq(200)
        expect(TopicLink.count).to eq(1)
      end

      it "doesn't allow updating of deleted posts" do
        first_post = post.topic.ordered_posts.first
        PostDestroyer.new(moderator, first_post).destroy

        put "/posts/#{first_post.id}.json", params: update_params
        expect(response).not_to be_successful
      end
    end

    describe "when logged in as staff" do
      before { sign_in(moderator) }

      it "supports updating posts in deleted topics" do
        first_post = post.topic.ordered_posts.first
        PostDestroyer.new(moderator, first_post).destroy

        put "/posts/#{first_post.id}.json", params: update_params
        expect(response.status).to eq(200)

        post.reload
        expect(post.raw).to eq("edited body")
      end

      it "won't update bump date if post is a whisper" do
        created_at = freeze_time 1.day.ago
        post = Fabricate(:post, post_type: Post.types[:whisper], user: user)

        unfreeze_time
        put "/posts/#{post.id}.json", params: update_params

        expect(response.status).to eq(200)
        expect(post.topic.reload.bumped_at).to eq_time(created_at)
      end
    end

    describe "when logged in as group moderator" do
      fab!(:topic) { Fabricate(:topic, category: category) }
      fab!(:post) { Fabricate(:post, user: user, topic: topic) }
      fab!(:group_user)
      let(:user_gm) { group_user.user }
      let(:group) { group_user.group }

      before do
        SiteSetting.enable_category_group_moderation = true
        Fabricate(:category_moderation_group, category: post.topic.category, group:)
        post.topic.category.update!(topic_id: topic.id)
        sign_in(user_gm)
      end

      it "allows updating the category description" do
        put "/posts/#{post.id}.json", params: update_params
        expect(response.status).to eq(200)

        post.reload
        expect(post.raw).to eq("edited body")
        expect(UserHistory.where(action: UserHistory.actions[:post_edit]).count).to eq(1)
      end

      it "can not update category descriptions in other categories" do
        second_category = Fabricate(:category)
        topic.update!(category: second_category)

        put "/posts/#{post.id}.json", params: update_params
        expect(response.status).to eq(403)
      end
    end

    it "can not change category to a disallowed category" do
      post = create_post
      sign_in(post.user)

      category = Fabricate(:category)
      category.set_permissions(staff: :full)
      category.save!

      put "/posts/#{post.id}.json",
          params: {
            post: {
              category_id: category.id,
              raw: "this is a test edit to post",
            },
          }

      expect(response.status).not_to eq(200)
      expect(post.topic.category_id).not_to eq(category.id)
    end

    it "can not move to a category that requires topic approval" do
      post = create_post
      sign_in(post.user)

      category = Fabricate(:category)
      category.require_topic_approval = true
      category.save!

      put "/posts/#{post.id}.json",
          params: {
            post: {
              category_id: category.id,
              raw: "this is a test edit to post",
            },
          }

      expect(response.status).to eq(403)
      expect(post.topic.reload.category_id).not_to eq(category.id)
    end

    describe "trying to add a link without permission" do
      it "returns an error message if links are added to posts when not allowed" do
        post = create_post
        sign_in(post.user)
        SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:admins]

        put "/posts/#{post.id}",
            params: {
              post: {
                raw: "I'm editing this post to add www.linkhere.com",
              },
            }

        expect(response.status).to eq(422)
        expect(response.body).to include("Sorry, you can't include links in your posts.")
      end
    end

    describe "with Post.plugin_permitted_update_params" do
      before do
        plugin = Plugin::Instance.new
        plugin.add_permitted_post_update_param(:random_number) do |post, value|
          post.custom_fields[:random_number] = value
          post.save
        end
      end

      after { DiscoursePluginRegistry.reset! }

      it "calls blocks passed into `add_permitted_post_update_param`" do
        sign_in(post.user)
        put "/posts/#{post.id}.json",
            params: {
              post: {
                raw: "this is a random post",
                raw_old: post.raw,
                random_number: 244,
              },
            }

        expect(response.status).to eq(200)
        expect(post.reload.custom_fields[:random_number]).to eq("244")
      end
    end
  end

  describe "#destroy_bookmark" do
    fab!(:post)
    fab!(:bookmark) { Fabricate(:bookmark, user: user, bookmarkable: post) }

    before { sign_in(user) }

    it "deletes the bookmark" do
      bookmark_id = bookmark.id
      delete "/posts/#{post.id}/bookmark.json"
      expect(Bookmark.find_by(id: bookmark_id)).to eq(nil)
    end

    context "when the user still has bookmarks in the topic" do
      before { Fabricate(:bookmark, user: user, bookmarkable: Fabricate(:post, topic: post.topic)) }
      it "marks topic_bookmarked as true" do
        delete "/posts/#{post.id}/bookmark.json"
        expect(response.parsed_body["topic_bookmarked"]).to eq(true)
      end
    end
  end

  describe "#wiki" do
    include_examples "action requires login", :put, "/posts/2/wiki.json"

    describe "when logged in" do
      before { sign_in(user) }

      let!(:post) { post_by_user }

      it "returns 400 when wiki parameter is not present" do
        sign_in(admin)

        put "/posts/#{post.id}/wiki.json", params: {}

        expect(response.status).to eq(400)
      end

      it "raises an error if the user doesn't have permission to wiki the post" do
        put "/posts/#{post.id}/wiki.json", params: { wiki: "true" }
        expect(response).to be_forbidden
      end

      it "toggle wiki status should create a new version" do
        sign_in(admin)
        another_user = Fabricate(:user)
        another_post = Fabricate(:post, user: another_user)

        expect do
          put "/posts/#{another_post.id}/wiki.json", params: { wiki: "true" }
        end.to change { another_post.reload.version }.by(1)

        expect do
          put "/posts/#{another_post.id}/wiki.json", params: { wiki: "false" }
        end.to change { another_post.reload.version }.by(-1)

        sign_in(Fabricate(:admin))

        expect do
          put "/posts/#{another_post.id}/wiki.json", params: { wiki: "true" }
        end.to change { another_post.reload.version }.by(1)
      end

      it "can wiki a post" do
        sign_in(admin)
        put "/posts/#{post.id}/wiki.json", params: { wiki: "true" }

        post.reload
        expect(post.wiki).to eq(true)
      end

      it "can unwiki a post" do
        wikied_post = Fabricate(:post, user: user, wiki: true)
        sign_in(admin)

        put "/posts/#{wikied_post.id}/wiki.json", params: { wiki: "false" }

        wikied_post.reload
        expect(wikied_post.wiki).to eq(false)
      end
    end
  end

  describe "#post_type" do
    include_examples "action requires login", :put, "/posts/2/post_type.json"

    describe "when logged in" do
      before { sign_in(moderator) }

      let!(:post) { post_by_user }

      it "raises an error if the user doesn't have permission to change the post type" do
        sign_in(user)

        put "/posts/#{post.id}/post_type.json", params: { post_type: 2 }
        expect(response).to be_forbidden
      end

      it "returns 400 if post_type parameter is not present" do
        put "/posts/#{post.id}/post_type.json", params: {}

        expect(response.status).to eq(400)
      end

      it "returns 400 if post_type parameters is invalid" do
        put "/posts/#{post.id}/post_type.json", params: { post_type: -1 }

        expect(response.status).to eq(400)
      end

      it "can change the post type" do
        put "/posts/#{post.id}/post_type.json", params: { post_type: 2 }

        post.reload
        expect(post.post_type).to eq(2)
      end
    end
  end

  describe "#rebake" do
    include_examples "action requires login", :put, "/posts/2/rebake.json"

    describe "when logged in" do
      let!(:post) { post_by_user }

      it "raises an error if the user doesn't have permission to rebake the post" do
        sign_in(user)
        put "/posts/#{post.id}/rebake.json"
        expect(response).to be_forbidden
      end

      it "can rebake the post" do
        sign_in(moderator)
        put "/posts/#{post.id}/rebake.json"
        expect(response.status).to eq(200)
      end

      it "will invalidate broken images cache" do
        sign_in(moderator)
        PostHotlinkedMedia.create!(
          url: "https://example.com/image.jpg",
          post: post,
          status: "download_failed",
        )
        put "/posts/#{post.id}/rebake.json"
        post.reload
        expect(post.post_hotlinked_media).to eq([])
      end
    end
  end

  describe "#create" do
    include_examples "action requires login", :post, "/posts.json"

    before do
      SiteSetting.min_first_post_typing_time = 0
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"
    end

    context "with api" do
      it "memoizes duplicate requests" do
        raw = "this is a test post 123 #{SecureRandom.hash}"
        title = "this is a title #{SecureRandom.hash}"

        master_key = Fabricate(:api_key).key

        post "/posts.json",
             params: {
               raw: raw,
               title: title,
               wpid: 1,
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)
        original = response.body

        post "/posts.json",
             params: {
               raw: raw,
               title: title,
               wpid: 2,
             },
             headers: {
               HTTP_API_USERNAME: user.username_lower,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)
        expect(response.body).to eq(original)
      end

      it "returns a valid JSON response when the post is enqueued" do
        SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]

        master_key = Fabricate(:api_key).key

        post "/posts.json",
             params: {
               raw: "this is test post #{SecureRandom.alphanumeric}",
               title: "this is a test title #{SecureRandom.alphanumeric}",
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)
        expect(response.parsed_body["action"]).to eq("enqueued")
      end

      it "allows to create posts in import_mode" do
        Jobs.run_immediately!
        NotificationEmailer.enable
        post_1 = Fabricate(:post)
        master_key = Fabricate(:api_key).key

        post "/posts.json",
             params: {
               raw: "this is test reply 1",
               topic_id: post_1.topic.id,
               reply_to_post_number: 1,
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)
        expect(post_1.topic.user.notifications.count).to eq(1)
        post_1.topic.user.notifications.destroy_all

        post "/posts.json",
             params: {
               raw: "this is test reply 2",
               topic_id: post_1.topic.id,
               reply_to_post_number: 1,
               import_mode: true,
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)
        expect(post_1.topic.user.notifications.count).to eq(0)

        post "/posts.json",
             params: {
               raw: "this is test reply 3",
               topic_id: post_1.topic.id,
               reply_to_post_number: 1,
               import_mode: false,
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)
        expect(post_1.topic.user.notifications.count).to eq(1)
      end

      it "allows a topic to be created with an external_id" do
        master_key = Fabricate(:api_key).key
        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is some post",
               external_id: "external_id",
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(200)

        new_topic = Topic.last

        expect(new_topic.external_id).to eq("external_id")
      end

      it "prevents whispers for regular users" do
        post_1 = Fabricate(:post)
        user_key = ApiKey.create!(user: user).key

        post "/posts.json",
             params: {
               raw: "this is test whisper",
               topic_id: post_1.topic.id,
               reply_to_post_number: 1,
               whisper: true,
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: user_key,
             }

        expect(response.status).to eq(403)
      end

      it "does not advance draft" do
        Draft.set(user, Draft::NEW_TOPIC, 0, "test")
        user_key = ApiKey.create!(user: user).key

        post "/posts.json",
             params: {
               title: "this is a test topic",
               raw: "this is test whisper",
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: user_key,
             }

        expect(response.status).to eq(200)
        expect(Draft.get(user, Draft::NEW_TOPIC, 0)).to eq("test")
      end

      it "will raise an error if specified category cannot be found" do
        user = Fabricate(:admin)
        master_key = Fabricate(:api_key).key

        post "/posts.json",
             params: {
               title: "this is a test title",
               raw: "this is test body",
               category: "invalid",
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(400)

        expect(response.parsed_body["errors"]).to include(
          I18n.t("invalid_params", message: "category"),
        )
      end

      it "will raise an error if specified embed_url is invalid" do
        user = Fabricate(:admin)
        master_key = Fabricate(:api_key).key

        post "/posts.json",
             params: {
               title: "this is a test title",
               raw: "this is test body",
               embed_url: "/test.txt",
             },
             headers: {
               HTTP_API_USERNAME: user.username,
               HTTP_API_KEY: master_key,
             }

        expect(response.status).to eq(422)
      end

      it "creates unlisted topic with admin master key" do
        master_key = Fabricate(:api_key).key

        expect do
          post "/posts.json",
               params: {
                 raw: "this is a test title",
                 title: "this is test body",
                 unlist_topic: true,
               },
               headers: {
                 HTTP_API_USERNAME: admin.username,
                 HTTP_API_KEY: master_key,
               }
        end.to change { Topic.count }.by(1)

        expect(response.status).to eq(200)
        expect(Topic.find(response.parsed_body["topic_id"]).visible).to eq(false)
      end

      it "prevents creation of unlisted topic with non-admin key" do
        user_key = ApiKey.create!(user: user).key

        expect do
          post "/posts.json",
               params: {
                 raw: "this is a test title",
                 title: "this is test body",
                 unlist_topic: true,
               },
               headers: {
                 HTTP_API_USERNAME: user.username,
                 HTTP_API_KEY: user_key,
               }
        end.not_to change { Topic.count }

        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(
          I18n.t("activerecord.errors.models.topic.attributes.base.unable_to_unlist"),
        )
      end
    end

    describe "when logged in" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

      before { sign_in(user) }

      context "when fast typing" do
        before do
          SiteSetting.min_first_post_typing_time = 3000
          SiteSetting.auto_silence_fast_typers_max_trust_level = 1
        end

        it "queues the post if min_first_post_typing_time is not met" do
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: "this is the test title for the topic",
                 composer_open_duration_msecs: 204,
                 typing_duration_msecs: 100,
                 reply_to_post_number: 123,
               }

          expect(response.status).to eq(200)
          parsed = response.parsed_body

          expect(parsed["action"]).to eq("enqueued")

          user.reload
          expect(user).to be_silenced

          rp = ReviewableQueuedPost.find_by(target_created_by: user)
          expect(rp.payload["typing_duration_msecs"]).to eq(100)
          expect(rp.payload["composer_open_duration_msecs"]).to eq(204)
          expect(rp.payload["reply_to_post_number"]).to eq(123)
          expect(rp.reviewable_scores.first.reason).to eq("fast_typer")

          expect(parsed["pending_post"]).to be_present
          expect(parsed["pending_post"]["id"]).to eq(rp.id)
          expect(parsed["pending_post"]["raw"]).to eq("this is the test content")

          mod = moderator
          rp.perform(mod, :approve_post)

          user.reload
          expect(user).not_to be_silenced
        end

        it "doesn't enqueue posts when user first creates a topic" do
          topic = Fabricate(:post, user: user).topic

          Draft.set(user, "should_clear", 0, "{'a' : 'b'}")

          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: "this is the test title for the topic",
                 composer_open_duration_msecs: 204,
                 typing_duration_msecs: 100,
                 topic_id: topic.id,
                 draft_key: "should_clear",
               }

          expect(response.status).to eq(200)
          parsed = response.parsed_body

          expect(parsed["action"]).not_to be_present

          expect { Draft.get(user, "should_clear", 0) }.to raise_error(Draft::OutOfSequence)
        end

        it "doesn't enqueue replies when the topic is closed" do
          topic = Fabricate(:closed_topic)

          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: "this is the test title for the topic",
                 topic_id: topic.id,
               }

          expect(response).not_to be_successful
          parsed = response.parsed_body
          expect(parsed["action"]).not_to eq("enqueued")
        end

        it "doesn't enqueue replies when the post is too long" do
          SiteSetting.max_post_length = 10

          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: "this is the test title for the topic",
               }

          expect(response).not_to be_successful
          parsed = response.parsed_body
          expect(parsed["action"]).not_to eq("enqueued")
        end

        it "doesn't enqueue replies when the post is too long (including a html comment)" do
          SiteSetting.max_post_length = 10
          raw = "A post <!-- " + ("a" * 3000) + "-->"

          post "/posts.json", params: { raw: raw, title: "this is the test title for the topic" }

          expect(response).not_to be_successful
          parsed = response.parsed_body
          expect(parsed["action"]).not_to eq("enqueued")
        end
      end

      it "silences correctly based on auto_silence_first_post_regex" do
        SiteSetting.auto_silence_first_post_regex = "I love candy|i eat s[1-5]"

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "when I eat s3 sometimes when not looking",
             }

        expect(response.status).to eq(200)
        parsed = response.parsed_body

        expect(parsed["action"]).to eq("enqueued")
        reviewable = ReviewableQueuedPost.find_by(target_created_by: user)
        score = reviewable.reviewable_scores.first
        expect(score.reason).to eq("auto_silence_regex")

        user.reload
        expect(user).to be_silenced
      end

      it "silences correctly based on silence watched words" do
        SiteSetting.watched_words_regular_expressions = true
        WatchedWord.create!(action: WatchedWord.actions[:silence], word: "I love candy")
        WatchedWord.create!(action: WatchedWord.actions[:silence], word: "i eat s[1-5]")

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "when I eat s3 sometimes when not looking",
             }

        expect(response.status).to eq(200)
        parsed = response.parsed_body

        expect(parsed["action"]).to eq("enqueued")
        reviewable = ReviewableQueuedPost.find_by(target_created_by: user)
        score = reviewable.reviewable_scores.first
        expect(score.reason).to eq("auto_silence_regex")

        user.reload
        expect(user).to be_silenced
      end

      it "can send a message to a group" do
        group = Group.create(name: "test_group", messageable_level: Group::ALIAS_LEVELS[:nobody])
        user1 = user
        group.add(user1)

        post "/posts.json",
             params: {
               raw: "I can haz a test",
               title: "I loves my test",
               target_recipients: group.name,
               archetype: Archetype.private_message,
             }

        expect(response).not_to be_successful

        # allow pm to this group
        group.update_columns(messageable_level: Group::ALIAS_LEVELS[:everyone])

        post "/posts.json",
             params: {
               raw: "I can haz a test",
               title: "I loves my test",
               target_recipients: "test_Group",
               archetype: Archetype.private_message,
             }

        expect(response.status).to eq(200)

        parsed = response.parsed_body
        post = Post.find(parsed["id"])

        expect(post.topic.topic_allowed_users.length).to eq(1)
        expect(post.topic.topic_allowed_groups.length).to eq(1)
      end

      it "can send a message to a group with caps" do
        group = Group.create(name: "Test_group", messageable_level: Group::ALIAS_LEVELS[:nobody])
        user1 = user
        group.add(user1)

        # allow pm to this group
        group.update_columns(messageable_level: Group::ALIAS_LEVELS[:everyone])

        post "/posts.json",
             params: {
               raw: "I can haz a test",
               title: "I loves my test",
               target_recipients: "test_Group",
               archetype: Archetype.private_message,
             }

        expect(response.status).to eq(200)

        parsed = response.parsed_body
        post = Post.find(parsed["id"])

        expect(post.topic.topic_allowed_users.length).to eq(1)
        expect(post.topic.topic_allowed_groups.length).to eq(1)
      end

      it "returns the nested post with a param" do
        post "/posts.json",
             params: {
               raw: "this is the test content  ",
               title: "this is the test title for the topic",
               nested_post: true,
             }

        expect(response.status).to eq(200)
        parsed = response.parsed_body
        expect(parsed["post"]).to be_present
        expect(parsed["post"]["raw"]).to eq("this is the test content")
        expect(parsed["post"]["cooked"]).to be_present
      end

      it "protects against dupes" do
        raw = "this is a test post 123 #{SecureRandom.hash}"
        title = "this is a title #{SecureRandom.hash}"

        expect do post "/posts.json", params: { raw: raw, title: title, wpid: 1 } end.to change {
          Post.count
        }

        expect(response.status).to eq(200)

        expect do
          post "/posts.json", params: { raw: raw, title: title, wpid: 2 }
        end.to_not change { Post.count }

        expect(response.status).to eq(422)
      end

      it "cannot create a post in a disallowed category" do
        category.set_permissions(staff: :full)
        category.save!

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is the test title for the topic",
               category: category.id,
             }

        expect(response.status).to eq(403)
      end

      it "cannot create a post with a tag that is restricted" do
        SiteSetting.tagging_enabled = true
        tag = Fabricate(:tag)
        category.allowed_tags = [tag.name]
        category.save!

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is the test title for the topic",
               tags: [tag.name],
             }

        expect(response.status).to eq(422)
        json = response.parsed_body
        expect(json["errors"]).to be_present
      end

      it "cannot create a post with a tag when tagging is disabled" do
        SiteSetting.tagging_enabled = false
        tag = Fabricate(:tag)

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is the test title for the topic",
               tags: [tag.name],
             }

        expect(response.status).to eq(422)
        json = response.parsed_body
        expect(json["errors"]).to be_present
      end

      it "cannot create a post with a tag without tagging permission" do
        SiteSetting.tagging_enabled = true
        SiteSetting.tag_topic_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        tag = Fabricate(:tag)

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is the test title for the topic",
               tags: [tag.name],
             }

        expect(response.status).to eq(422)
        json = response.parsed_body
        expect(json["errors"]).to be_present
      end

      it "can create a post with a tag when tagging is enabled" do
        SiteSetting.tagging_enabled = true
        tag = Fabricate(:tag)

        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is the test title for the topic",
               tags: [tag.name],
             }

        expect(response.status).to eq(200)
        expect(Post.last.topic.tags.count).to eq(1)
      end

      it "creates the topic and post with the right attributes" do
        post "/posts.json",
             params: {
               raw: "this is the test content",
               title: "this is the test title for the topic",
               category: category.id,
             }

        expect(response.status).to eq(200)

        new_post = Post.last
        topic = new_post.topic

        expect(new_post.user).to eq(user)
        expect(new_post.raw).to eq("this is the test content")
        expect(topic.title).to eq("This is the test title for the topic")
        expect(topic.category).to eq(category)
        expect(topic.visible).to eq(true)
      end

      context "when adding custom fields to topic via the `topic_custom_fields` param" do
        it "should return a 400 response code when no custom fields has been permitted" do
          sign_in(user)

          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: "this is the test title for the topic",
                 category: category.id,
                 topic_custom_fields: {
                   xyz: "abc",
                   abc: "xyz",
                 },
               }

          expect(response.status).to eq(400)
          expect(Topic.last.custom_fields).to eq({})
        end

        context "when custom fields has been permitted" do
          fab!(:plugin) do
            plugin = Plugin::Instance.new
            plugin.register_editable_topic_custom_field(:xyz)
            plugin.register_editable_topic_custom_field(:abc, staff_only: true)
            plugin
          end

          it "should return a 400 response when trying to add a staff ony custom field for a non-staff user" do
            sign_in(user)

            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   title: "this is the test title for the topic",
                   category: category.id,
                   topic_custom_fields: {
                     abc: "xyz",
                   },
                 }

            expect(response.status).to eq(400)
            expect(Topic.last.custom_fields).to eq({})
          end

          it "should add custom fields to topic that is permitted for a non-staff user" do
            sign_in(user)

            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   title: "this is the test title for the topic",
                   category: category.id,
                   topic_custom_fields: {
                     xyz: "abc",
                   },
                 }

            expect(response.status).to eq(200)
            expect(Topic.last.custom_fields).to eq({ "xyz" => "abc" })
          end

          it "should add custom fields to topic that is permitted for a non-staff user via the deprecated `meta_data` param" do
            sign_in(user)

            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   title: "this is the test title for the topic",
                   category: category.id,
                   meta_data: {
                     xyz: "abc",
                   },
                 }

            expect(response.status).to eq(200)
            expect(Topic.last.custom_fields).to eq({ "xyz" => "abc" })
          end

          it "should add custom fields to topic that is permitted for a staff user and public user" do
            sign_in(Fabricate(:admin))

            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   title: "this is the test title for the topic",
                   category: category.id,
                   topic_custom_fields: {
                     xyz: "abc",
                     abc: "xyz",
                   },
                 }

            expect(response.status).to eq(200)
            expect(Topic.last.custom_fields).to eq({ "xyz" => "abc", "abc" => "xyz" })
          end
        end
      end

      it "can create an uncategorized topic" do
        title = "this is the test title for the topic"

        expect do
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: title,
                 category: "",
               }

          expect(response.status).to eq(200)
        end.to change { Topic.count }.by(1)

        topic = Topic.last

        expect(topic.title).to eq(title.capitalize)
        expect(topic.category_id).to eq(SiteSetting.uncategorized_category_id)
      end

      it "can create a reply to a post" do
        topic = Fabricate(:private_message_post, user: user).topic
        post_2 = Fabricate(:private_message_post, user: user, topic: topic)

        post "/posts.json",
             params: {
               raw: "this is the test content",
               topic_id: topic.id,
               reply_to_post_number: post_2.post_number,
               image_sizes: {
                 width: "100",
                 height: "200",
               },
             }

        expect(response.status).to eq(200)

        new_post = Post.last
        topic = new_post.topic

        expect(new_post.user).to eq(user)
        expect(new_post.raw).to eq("this is the test content")
        expect(new_post.reply_to_post_number).to eq(post_2.post_number)

        job_args = Jobs::ProcessPost.jobs.first["args"].first

        expect(job_args["image_sizes"]).to eq("width" => "100", "height" => "200")
      end

      it "creates a private post" do
        user_2 = Fabricate(:user)
        user_3 = Fabricate(:user, username: "foo_bar")

        # In certain edge cases, it's possible to end up with a username
        # containing characters that would normally fail to validate
        user_4 = Fabricate(:user, username: "Iyi_Iyi")
        user_4.update_attribute(:username, "İyi_İyi")
        user_4.update_attribute(:username_lower, "İyi_İyi".downcase)

        post "/posts.json",
             params: {
               raw: "this is the test content",
               archetype: "private_message",
               title: "this is some post",
               target_recipients: "#{user_2.username},Foo_Bar,İyi_İyi",
             }

        expect(response.status).to eq(200)

        new_post = Post.last
        new_topic = Topic.last

        expect(new_post.user).to eq(user)
        expect(new_topic.private_message?).to eq(true)
        expect(new_topic.allowed_users).to contain_exactly(user, user_2, user_3, user_4)
      end

      context "when target_recipients not provided" do
        it "errors when creating a private post" do
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 archetype: "private_message",
                 title: "this is some post",
                 target_recipients: "",
               }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("activerecord.errors.models.topic.attributes.base.no_user_selected"),
          )
        end
      end

      context "when topic_id is set" do
        fab!(:topic)

        it "errors when creating a private post" do
          user_2 = Fabricate(:user)

          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 archetype: "private_message",
                 title: "this is some post",
                 target_recipients: user_2.username,
                 topic_id: topic.id,
               }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(I18n.t("create_pm_on_existing_topic"))
        end
      end

      context "with errors" do
        it "does not succeed" do
          post "/posts.json", params: { raw: "test" }
          expect(response).not_to be_successful
          expect(response.status).to eq(422)
        end

        it "it triggers flag_linked_posts_as_spam when the post creator returns spam" do
          SiteSetting.newuser_spam_host_threshold = 1
          sign_in(Fabricate(:user, trust_level: TrustLevel[0]))

          post "/posts.json",
               params: {
                 raw:
                   "this is the test content http://fakespamwebsite.com http://fakespamwebsite.com/spam http://fakespamwebsite.com/spammy",
                 title: "this is the test title for the topic",
               }

          expect(response.parsed_body["errors"]).to include(I18n.t(:spamming_host))
        end

        context "when allow_uncategorized_topics is false" do
          before { SiteSetting.allow_uncategorized_topics = false }

          it "cant create an uncategorized post" do
            post "/posts.json",
                 params: {
                   raw: "a new post with no category",
                   title: "a new post with no category",
                 }
            expect(response).not_to be_successful
          end

          context "as staff" do
            before { sign_in(admin) }

            it "cant create an uncategorized post" do
              post "/posts.json",
                   params: {
                     raw: "a new post with no category",
                     title: "a new post with no category",
                   }
              expect(response).not_to be_successful
            end
          end
        end
      end

      context "when `enable_user_status` site setting is enabled" do
        fab!(:user_to_mention) { Fabricate(:user) }

        before { SiteSetting.enable_user_status = true }

        it "does not return mentioned users when `enable_user_status` site setting is disabled" do
          SiteSetting.enable_user_status = false

          post "/posts.json",
               params: {
                 raw: "I am mentioning @#{user_to_mention.username}",
                 topic_id: topic.id,
               }

          expect(response.status).to eq(200)

          json = response.parsed_body

          expect(json["mentioned_users"]).to eq(nil)
        end

        it "returns mentioned users" do
          user_to_mention.set_status!("off to dentist", "tooth")

          post "/posts.json",
               params: {
                 raw: "I am mentioning @#{user_to_mention.username}",
                 topic_id: topic.id,
               }

          expect(response.status).to eq(200)
          json = response.parsed_body
          expect(json["mentioned_users"].length).to be(1)

          mentioned_user = json["mentioned_users"][0]
          expect(mentioned_user["id"]).to be(user_to_mention.id)
          expect(mentioned_user["name"]).to eq(user_to_mention.name)
          expect(mentioned_user["username"]).to eq(user_to_mention.username)

          status = mentioned_user["status"]
          expect(status).to be_present
          expect(status["emoji"]).to eq(user_to_mention.user_status.emoji)
          expect(status["description"]).to eq(user_to_mention.user_status.description)
        end

        it "returns an empty list of mentioned users if nobody was mentioned" do
          post "/posts.json", params: { raw: "No mentions here", topic_id: topic.id }

          expect(response.status).to eq(200)
          expect(response.parsed_body["mentioned_users"].length).to be(0)
        end

        it "returns an empty list of mentioned users if an nonexistent user was mentioned" do
          post "/posts.json", params: { raw: "Mentioning a @stranger", topic_id: topic.id }

          expect(response.status).to eq(200)
          expect(response.parsed_body["mentioned_users"].length).to be(0)
        end
      end
    end

    context "with topic unlisting" do
      context "when logged in as staff" do
        before { sign_in(admin) }

        it "creates an unlisted topic" do
          expect do
            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   title: "this is the test title for the topic",
                   unlist_topic: true,
                 }
          end.to change { Topic.count }.by(1)

          expect(response.status).to eq(200)
          expect(Topic.find(response.parsed_body["topic_id"]).visible).to eq(false)
        end
      end

      context "when logged in as a non-staff user" do
        before { sign_in(user) }

        it "prevents creation of an unlisted topic" do
          expect do
            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   title: "this is the test title for the topic",
                   unlist_topic: true,
                 }
          end.not_to change { Topic.count }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("activerecord.errors.models.topic.attributes.base.unable_to_unlist"),
          )
        end
      end
    end

    describe "shared draft" do
      fab!(:destination_category) { Fabricate(:category) }

      it "will raise an error for regular users" do
        post "/posts.json",
             params: {
               raw: "this is the shared draft content",
               title: "this is the shared draft title",
               category: destination_category.id,
               shared_draft: "true",
             }
        expect(response).not_to be_successful
      end

      describe "as a staff user" do
        before { sign_in(moderator) }

        it "will raise an error if there is no shared draft category" do
          post "/posts.json",
               params: {
                 raw: "this is the shared draft content",
                 title: "this is the shared draft title",
                 category: destination_category.id,
                 shared_draft: "true",
               }
          expect(response).not_to be_successful
        end

        context "with a shared category" do
          fab!(:shared_category) { Fabricate(:category) }
          before { SiteSetting.shared_drafts_category = shared_category.id }

          it "will work if the shared draft category is present" do
            post "/posts.json",
                 params: {
                   raw: "this is the shared draft content",
                   title: "this is the shared draft title",
                   category: destination_category.id,
                   shared_draft: "true",
                 }
            expect(response.status).to eq(200)
            result = response.parsed_body
            topic = Topic.find(result["topic_id"])
            expect(topic.category_id).to eq(shared_category.id)
            expect(topic.shared_draft.category_id).to eq(destination_category.id)
          end
        end
      end
    end

    describe "warnings" do
      fab!(:user_2) { Fabricate(:user, refresh_auto_groups: true) }

      context "as a staff user" do
        before { sign_in(admin) }

        it "should be able to mark a topic as warning" do
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 archetype: "private_message",
                 title: "this is some post",
                 target_recipients: user_2.username,
                 is_warning: true,
               }

          expect(response.status).to eq(200)

          new_topic = Topic.last

          expect(new_topic.title).to eq("This is some post")
          expect(new_topic.is_official_warning?).to eq(true)
        end

        it "should be able to mark a topic as not a warning" do
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 archetype: "private_message",
                 title: "this is some post",
                 target_recipients: user_2.username,
                 is_warning: false,
               }

          expect(response.status).to eq(200)

          new_topic = Topic.last

          expect(new_topic.title).to eq("This is some post")
          expect(new_topic.is_official_warning?).to eq(false)
        end
      end

      context "as a normal user" do
        it "should not be able to mark a topic as warning" do
          sign_in(user)
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 archetype: "private_message",
                 title: "this is some post",
                 target_recipients: user_2.username,
                 is_warning: true,
               }

          expect(response.status).to eq(200)

          new_topic = Topic.last

          expect(new_topic.title).to eq("This is some post")
          expect(new_topic.is_official_warning?).to eq(false)
        end
      end
    end

    context "with topic bump" do
      shared_examples "it works" do
        it "should be able to skip topic bumping" do
          original_bumped_at = 1.day.ago
          topic = Fabricate(:topic, bumped_at: original_bumped_at)

          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 topic_id: topic.id,
                 no_bump: true,
               }

          expect(response.status).to eq(200)
          expect(topic.reload.bumped_at).to eq_time(original_bumped_at)
        end

        it "should be able to post with topic bumping" do
          post "/posts.json", params: { raw: "this is the test content", topic_id: topic.id }

          expect(response.status).to eq(200)
          expect(topic.reload.bumped_at).to eq_time(topic.posts.last.created_at)
        end
      end

      context "with admins" do
        before { sign_in(admin) }

        include_examples "it works"
      end

      context "with moderators" do
        before { sign_in(moderator) }

        include_examples "it works"
      end

      context "with TL4 users" do
        fab!(:trust_level_4)

        before { sign_in(trust_level_4) }

        include_examples "it works"
      end

      context "with users" do
        fab!(:topic)

        [:user].each do |user|
          it "will raise an error for #{user}" do
            sign_in(Fabricate(user))
            post "/posts.json",
                 params: {
                   raw: "this is the test content",
                   topic_id: topic.id,
                   no_bump: true,
                 }
            expect(response.status).to eq(400)
          end
        end
      end
    end

    context "with featured links" do
      it "allows to create topics with featured links" do
        sign_in(user_trust_level_1)

        post "/posts.json",
             params: {
               title: "this is the test title for the topic",
               raw: "this is the test content",
               featured_link: "https://discourse.org",
             }

        expect(response.status).to eq(200)
      end

      it "doesn't allow TL0 users to create topics with featured links" do
        sign_in(user_trust_level_0)

        post "/posts.json",
             params: {
               title: "this is the test title for the topic",
               raw: "this is the test content",
               featured_link: "https://discourse.org",
             }

        expect(response.status).to eq(422)
      end

      it "doesn't allow to create topics with featured links if featured links are disabled in settings" do
        SiteSetting.topic_featured_link_enabled = false
        sign_in(user_trust_level_1)

        post "/posts.json",
             params: {
               title: "this is the test title for the topic",
               raw: "this is the test content",
               featured_link: "https://discourse.org",
             }

        expect(response.status).to eq(422)
      end

      it "doesn't allow to create topics with featured links in the category with forbidden feature links" do
        category = Fabricate(:category, topic_featured_link_allowed: false)
        sign_in(user_trust_level_1)

        post "/posts.json",
             params: {
               title: "this is the test title for the topic",
               raw: "this is the test content",
               featured_link: "https://discourse.org",
               category: category.id,
             }

        expect(response.status).to eq(422)
      end
    end
  end

  describe "#revisions" do
    fab!(:post) { Fabricate(:post, version: 2) }
    let(:post_revision) { Fabricate(:post_revision, post: post) }

    it "throws an exception when revision is < 2" do
      get "/posts/#{post.id}/revisions/1.json"
      expect(response.status).to eq(400)
    end

    context "when edit history is not visible to the public" do
      before { SiteSetting.edit_history_visible_to_public = false }

      it "ensures anonymous cannot see the revisions" do
        get "/posts/#{post.id}/revisions/#{post_revision.number}.json"
        expect(response).to be_forbidden
      end

      it "ensures regular user cannot see the revisions" do
        sign_in(user)
        get "/posts/#{post.id}/revisions/#{post_revision.number}.json"
        expect(response).to be_forbidden
      end

      it "ensures staff can see the revisions" do
        sign_in(admin)
        get "/posts/#{post.id}/revisions/#{post_revision.number}.json"
        expect(response.status).to eq(200)
      end

      it "ensures poster can see the revisions" do
        user = Fabricate(:active_user)
        sign_in(user)

        post = Fabricate(:post, user: user, version: 3)
        pr = Fabricate(:post_revision, user: user, post: post)

        get "/posts/#{pr.post_id}/revisions/#{pr.number}.json"
        expect(response.status).to eq(200)
      end

      it "ensures trust level 4 cannot see the revisions" do
        sign_in(Fabricate(:user, trust_level: 4))
        get "/posts/#{post_revision.post_id}/revisions/#{post_revision.number}.json"
        expect(response.status).to eq(403)
      end
    end

    context "when the history on a specific post is hidden" do
      it "works when hiding a revision" do
        sign_in(admin)

        message =
          MessageBus
            .track_publish("/topic/#{post.topic.id}") do
              put "/posts/#{post_revision.post_id}/revisions/#{post_revision.number}/hide"
            end
            .first

        expect(response.status).to eq(200)
        expect(message.data[:type]).to eq(:revised)
        expect(message.data[:version]).to eq(2)
        expect(post_revision.reload[:hidden]).to eq(true)
      end

      it "works when showing a revision" do
        post_revision.update!(hidden: true)
        sign_in(admin)

        message =
          MessageBus
            .track_publish("/topic/#{post.topic.id}") do
              put "/posts/#{post_revision.post_id}/revisions/#{post_revision.number}/show"
            end
            .first

        expect(response.status).to eq(200)
        expect(message.data[:type]).to eq(:revised)
        expect(message.data[:version]).to eq(2)
        expect(post_revision.reload[:hidden]).to eq(false)
      end
    end

    context "when post is hidden" do
      before do
        post.hidden = true
        post.save
      end

      it "throws an exception for users" do
        sign_in(user)
        get "/posts/#{post.id}/revisions/#{post_revision.number}.json"
        expect(response.status).to eq(403)
      end

      it "works for admins" do
        sign_in(admin)
        get "/posts/#{post.id}/revisions/#{post_revision.number}.json"
        expect(response.status).to eq(200)
      end
    end

    context "when edit history is visible to everyone" do
      before { SiteSetting.edit_history_visible_to_public = true }

      it "ensures anyone can see the revisions" do
        get "/posts/#{post_revision.post_id}/revisions/#{post_revision.number}.json"
        expect(response.status).to eq(200)
      end
    end

    context "with deleted post" do
      fab!(:deleted_post) { Fabricate(:post, user: admin, version: 3) }
      fab!(:deleted_post_revision) { Fabricate(:post_revision, user: admin, post: deleted_post) }

      before { deleted_post.trash!(admin) }

      it "also work on deleted post" do
        sign_in(admin)
        get "/posts/#{deleted_post_revision.post_id}/revisions/#{deleted_post_revision.number}.json"
        expect(response.status).to eq(200)
      end
    end

    context "with deleted topic" do
      fab!(:deleted_topic) { Fabricate(:topic, user: admin) }
      fab!(:post) { Fabricate(:post, user: admin, topic: deleted_topic, version: 3) }
      fab!(:post_revision) { Fabricate(:post_revision, user: admin, post: post) }

      before { deleted_topic.trash!(admin) }

      it "also work on deleted topic" do
        sign_in(admin)
        get "/posts/#{post_revision.post_id}/revisions/#{post_revision.number}.json"
        expect(response.status).to eq(200)
      end
    end

    context "with a tagged topic" do
      let(:tag) { Fabricate(:tag) }
      it "works" do
        SiteSetting.tagging_enabled = true

        post_revision.post.topic.update(tags: [tag])

        get "/posts/#{post_revision.post_id}/revisions/latest.json"
        expect(response.status).to eq(200)

        SiteSetting.tagging_enabled = false

        get "/posts/#{post_revision.post_id}/revisions/latest.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#permanently_delete_revisions" do
    before { SiteSetting.can_permanently_delete = true }

    fab!(:post) do
      Fabricate(
        :post,
        user: Fabricate(:user),
        raw: "Lorem ipsum dolor sit amet, cu nam libris tractatos, ancillae senserit ius ex",
      )
    end

    fab!(:post_with_no_revisions) do
      Fabricate(
        :post,
        user: Fabricate(:user),
        raw: "Lorem ipsum dolor sit amet, cu nam libris tractatos, ancillae senserit ius ex",
      )
    end

    fab!(:post_revision) { Fabricate(:post_revision, post: post) }
    fab!(:post_revision_2) { Fabricate(:post_revision, post: post) }

    let(:post_id) { post.id }

    describe "when logged in as a regular user" do
      it "does not delete revisions" do
        sign_in(user)
        delete "/posts/#{post_id}/revisions/permanently_delete.json"
        expect(response).to_not be_successful
      end
    end

    describe "when logged in as staff" do
      before { sign_in(admin) }

      it "fails when post record is not found" do
        delete "/posts/#{post_id + 1}/revisions/permanently_delete.json"
        expect(response).to_not be_successful
      end

      it "fails when no post revisions are found" do
        delete "/posts/#{post_with_no_revisions.id}/revisions/permanently_delete.json"
        expect(response).to_not be_successful
      end

      it "fails when 'can_permanently_delete' setting is false" do
        SiteSetting.can_permanently_delete = false
        delete "/posts/#{post_id}/revisions/permanently_delete.json"
        expect(response).to_not be_successful
      end

      it "permanently deletes revisions from post and adds a staff log" do
        delete "/posts/#{post_id}/revisions/permanently_delete.json"
        expect(response.status).to eq(200)

        # It creates a staff log
        logs =
          UserHistory.find_by(
            action: UserHistory.actions[:permanently_delete_post_revisions],
            acting_user_id: admin.id,
            post_id: post_id,
          )
        expect(logs).to be_present

        # ensure post revisions are deleted
        expect(PostRevision.where(post: post)).to eq([])
      end
    end
  end

  describe "#revert" do
    include_examples "action requires login", :put, "/posts/123/revisions/2/revert.json"

    fab!(:post) do
      Fabricate(
        :post,
        user: Fabricate(:user),
        raw: "Lorem ipsum dolor sit amet, cu nam libris tractatos, ancillae senserit ius ex",
      )
    end
    let(:post_revision) do
      Fabricate(
        :post_revision,
        post: post,
        modifications: {
          "raw" => ["this is original post body.", "this is edited post body."],
        },
      )
    end
    let(:blank_post_revision) do
      Fabricate(
        :post_revision,
        post: post,
        modifications: {
          "edit_reason" => ["edit reason #1", "edit reason #2"],
        },
      )
    end
    let(:same_post_revision) do
      Fabricate(
        :post_revision,
        post: post,
        modifications: {
          "raw" => [
            "Lorem ipsum dolor sit amet, cu nam libris tractatos, ancillae senserit ius ex",
            "this is edited post body.",
          ],
        },
      )
    end

    let(:post_id) { post.id }
    let(:revision_id) { post_revision.number }

    describe "when logged in as a regular user" do
      it "does not work" do
        sign_in(user)
        put "/posts/#{post_id}/revisions/#{revision_id}/revert.json"
        expect(response).to_not be_successful
      end
    end

    describe "when logged in as staff" do
      before { sign_in(moderator) }

      it "fails when revision is < 2" do
        put "/posts/#{post_id}/revisions/1/revert.json"
        expect(response.status).to eq(400)
      end

      it "fails when post_revision record is not found" do
        put "/posts/#{post_id}/revisions/#{revision_id + 1}/revert.json"
        expect(response).to_not be_successful
      end

      it "fails when post record is not found" do
        put "/posts/#{post_id + 1}/revisions/#{revision_id}/revert.json"
        expect(response).to_not be_successful
      end

      it "fails when revision is blank" do
        put "/posts/#{post_id}/revisions/#{blank_post_revision.number}/revert.json"
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("revert_version_same"))
      end

      it "fails when revised version is same as current version" do
        put "/posts/#{post_id}/revisions/#{same_post_revision.number}/revert.json"
        expect(response.status).to eq(422)
        expect(response.parsed_body["errors"]).to include(I18n.t("revert_version_same"))
      end

      it "works!" do
        put "/posts/#{post_id}/revisions/#{revision_id}/revert.json"
        expect(response.status).to eq(200)
      end

      it "supports reverting posts in deleted topics" do
        first_post = post.topic.ordered_posts.first
        PostDestroyer.new(moderator, first_post).destroy

        put "/posts/#{post_id}/revisions/#{revision_id}/revert.json"
        expect(response.status).to eq(200)
      end
    end
  end

  describe "#expand_embed" do
    before { sign_in(user) }

    fab!(:post)

    it "raises an error when you can't see the post" do
      post = Fabricate(:private_message_post)
      get "/posts/#{post.id}/expand-embed.json"
      expect(response).not_to be_successful
    end

    it "retrieves the body when you can see the post" do
      TopicEmbed.expects(:expanded_for).with(post).returns("full content")
      get "/posts/#{post.id}/expand-embed.json"
      expect(response.status).to eq(200)
      expect(response.parsed_body["cooked"]).to eq("full content")
    end
  end

  describe "#deleted_posts" do
    include_examples "action requires login", :get, "/posts/system/deleted.json"

    describe "when logged in" do
      it "raises an error if the user doesn't have permission to see the deleted posts" do
        sign_in(user)
        get "/posts/system/deleted.json"
        expect(response).to be_forbidden
      end

      describe "when limit params is invalid" do
        before { sign_in(moderator) }

        include_examples "invalid limit params",
                         "/posts/system/deleted.json",
                         described_class::DELETED_POSTS_MAX_LIMIT
      end

      it "can see the deleted posts when authorized" do
        sign_in(moderator)
        get "/posts/system/deleted.json"
        expect(response.status).to eq(200)
      end

      it "does not raise if topic has been permanently deleted" do
        post = Fabricate(:post, user: admin)
        PostDestroyer.new(admin, post).destroy
        post.update!(topic_id: -1000)

        sign_in(admin)
        get "/posts/#{admin.username}/deleted.json"
        expect(response.status).to eq(200)
      end

      it "doesn't return secured categories for moderators if they don't have access" do
        Fabricate(:moderator)

        group = Fabricate(:group)
        group.add_owner(user)

        secured_category = Fabricate(:private_category, group: group)
        secured_post = create_post(user: user, category: secured_category)
        PostDestroyer.new(admin, secured_post).destroy

        sign_in(moderator)
        get "/posts/#{user.username}/deleted.json"
        expect(response.status).to eq(200)

        data = response.parsed_body
        expect(data.length).to eq(0)
      end

      it "doesn't return PMs for moderators" do
        Fabricate(:moderator)

        pm_post =
          create_post(user: user, archetype: "private_message", target_usernames: [admin.username])
        PostDestroyer.new(admin, pm_post).destroy

        sign_in(moderator)
        get "/posts/#{user.username}/deleted.json"
        expect(response.status).to eq(200)

        data = response.parsed_body
        expect(data.length).to eq(0)
      end

      it "only shows posts deleted by other users" do
        create_post(user: user)
        post_deleted_by_user = create_post(user: user)
        post_deleted_by_admin = create_post(user: user)

        PostDestroyer.new(user, post_deleted_by_user).destroy
        PostDestroyer.new(admin, post_deleted_by_admin).destroy

        sign_in(admin)
        get "/posts/#{user.username}/deleted.json"
        expect(response.status).to eq(200)

        data = response.parsed_body
        expect(data.length).to eq(1)
        expect(data[0]["id"]).to eq(post_deleted_by_admin.id)
        expect(data[0]["deleted_by"]["id"]).to eq(admin.id)
      end
    end
  end

  describe "#markdown_id" do
    it "can be viewed by anonymous" do
      post = Fabricate(:post, raw: "123456789")
      get "/posts/#{post.id}/raw.json"
      expect(response.status).to eq(200)
      expect(response.body).to eq("123456789")
    end

    it "renders a 404 page" do
      get "/posts/0/raw"
      expect(response.status).to eq(404)
      expect(response.body).to include(I18n.t("page_not_found.title"))
    end
  end

  describe "#markdown_num" do
    it "can be viewed by anonymous" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, post_number: 1, raw: "123456789")
      post.save
      get "/raw/#{topic.id}/1.json"
      expect(response.status).to eq(200)
      expect(response.body).to eq("123456789")
    end

    it "can show whole topics" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, post_number: 1, raw: "123456789")
      _post_2 = Fabricate(:post, topic: topic, post_number: 2, raw: "abcdefghij")
      post.save
      get "/raw/#{topic.id}"
      expect(response.status).to eq(200)
      expect(response.body).to include("123456789", "abcdefghij")
    end
  end

  describe "#short_link" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "redirects to the topic" do
      get "/p/#{post.id}.json"
      expect(response).to be_redirect
    end

    it "returns a 403 when access is denied for JSON format" do
      post = Fabricate(:private_message_post)
      get "/p/#{post.id}.json"
      expect(response).to be_forbidden
    end

    it "returns a 403 when access is denied for HTML format" do
      post = Fabricate(:private_message_post)
      get "/p/#{post.id}"
      expect(response).to be_forbidden
      expect(response.body).to have_tag("body.no-ember")
    end

    it "renders a 404 page" do
      get "/p/0"
      expect(response.status).to eq(404)
      expect(response.body).to include(I18n.t("page_not_found.title"))
    end
  end

  describe "#user_posts_feed" do
    it "returns public posts rss feed" do
      public_post
      private_post

      get "/u/#{user.username}/activity.rss"

      expect(response.status).to eq(200)

      body = response.body

      expect(body).to_not include(private_post.url)
      expect(body).to include(public_post.url)
    end

    it "doesn't include posts from hidden topics" do
      public_post.topic.update!(visible: false)

      get "/u/#{user.username}/activity.rss"

      expect(response.status).to eq(200)

      body = response.body
      expect(body).not_to include(public_post.url)
    end

    it "excludes small actions" do
      small_action = Fabricate(:small_action, user: user)

      get "/u/#{user.username}/activity.rss"

      expect(response.status).to eq(200)

      body = response.body

      expect(body).not_to include(small_action.canonical_url)
    end

    it "returns public posts as JSON" do
      public_post
      private_post

      get "/u/#{user.username}/activity.json"

      expect(response.status).to eq(200)

      body = response.body

      expect(body).to_not include(private_post.topic.slug)
      expect(body).to include(public_post.topic.slug)
    end

    it "returns 404 if `hide_profile_and_presence` user option is checked" do
      user.user_option.update_columns(hide_profile_and_presence: true)

      get "/u/#{user.username}/activity.rss"
      expect(response.status).to eq(404)

      get "/u/#{user.username}/activity.json"
      expect(response.status).to eq(404)
    end

    it "succeeds when `allow_users_to_hide_profile` is false" do
      user.user_option.update_columns(hide_profile_and_presence: true)
      SiteSetting.allow_users_to_hide_profile = false

      get "/u/#{user.username}/activity.rss"
      expect(response.status).to eq(200)

      get "/u/#{user.username}/activity.json"
      expect(response.status).to eq(200)
    end
  end

  describe "#latest" do
    context "with private posts" do
      describe "when not logged in" do
        it "should return the right response" do
          Fabricate(:post)

          get "/private-posts.rss"

          expect(response.status).to eq(404)

          expect(response.body).to have_tag("input", with: { value: "private_posts" })
        end
      end

      it "returns private posts rss feed" do
        sign_in(admin)

        public_post
        private_post
        get "/private-posts.rss"

        expect(response.status).to eq(200)

        body = response.body

        expect(body).to include(private_post.url)
        expect(body).to_not include(public_post.url)
      end

      it "properly secures private posts" do
        sign_in(user)

        private_post

        pm = Fabricate(:private_message_topic, recipient: user)
        post_id = Fabricate(:post, topic: pm).id

        get "/private-posts.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        post_ids = json["private_posts"].map { |p| p["id"] }

        expect(post_ids).to eq([post_id])
      end

      it "returns private posts for json" do
        sign_in(admin)

        public_post
        private_post
        get "/private-posts.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        post_ids = json["private_posts"].map { |p| p["id"] }

        expect(post_ids).to include private_post.id
        expect(post_ids).to_not include public_post.id
      end
    end

    context "with public posts" do
      it "returns public posts with topic rss feed" do
        public_post
        private_post

        get "/posts.rss"

        expect(response.status).to eq(200)

        body = response.body

        # we cache in redis, in rare cases this can cause a flaky test
        PostsHelper.clear_canonical_cache!(public_post)

        expect(body).to include(public_post.canonical_url)
        expect(body).to_not include(private_post.url)
      end

      it "doesn't include posts from secured categories you have no access to" do
        public_post
        private_post

        category = Fabricate(:category, read_restricted: true)
        topic = Fabricate(:topic, category: category)
        secure_post = Fabricate(:post, topic: topic)

        get "/posts.json"

        expect(response.status).to eq(200)

        body = response.parsed_body
        ids = body["latest_posts"].map { |p| p["id"] }

        expect(ids).not_to include secure_post.id
      end

      it "doesn't include posts from hidden topics" do
        public_post.topic.update!(visible: false)

        get "/posts.rss"

        expect(response.status).to eq(200)

        body = response.body

        # we cache in redis, in rare cases this can cause a flaky test
        PostsHelper.clear_canonical_cache!(public_post)

        expect(body).not_to include(public_post.canonical_url)
      end

      it "excludes small actions" do
        small_action = Fabricate(:small_action)

        get "/posts.rss"

        expect(response.status).to eq(200)

        body = response.body

        expect(body).not_to include(small_action.canonical_url)
      end

      it "returns public posts with topic for json" do
        topicless_post.update topic_id: -100

        public_post
        private_post
        topicless_post

        get "/posts.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        post_ids = json["latest_posts"].map { |p| p["id"] }

        expect(post_ids).to include public_post.id
        expect(post_ids).to_not include private_post.id
        expect(post_ids).to_not include topicless_post.id
      end
    end
  end

  describe "#cooked" do
    it "returns the cooked content" do
      post = Fabricate(:post, cooked: "WAt")
      get "/posts/#{post.id}/cooked.json"

      expect(response.status).to eq(200)
      json = response.parsed_body

      expect(json).to be_present
      expect(json["cooked"]).to eq("WAt")
    end
  end

  describe "#raw_email" do
    include_examples "action requires login", :get, "/posts/2/raw-email.json"

    describe "when logged in" do
      let(:post) do
        Fabricate(
          :post,
          deleted_at: 2.hours.ago,
          user: Fabricate(:user),
          raw_email: "email_content",
        )
      end

      it "returns 403 when trying to view raw as user that created the post" do
        sign_in(post.user)

        get "/posts/#{post.id}/raw-email.json"
        expect(response.status).to eq(403)
      end

      it "returns 403 when trying to view raw email as a normal user" do
        sign_in(user)

        get "/posts/#{post.id}/raw-email.json"
        expect(response.status).to eq(403)
      end

      it "can view raw email if the user is in the allowed group" do
        sign_in(user)
        SiteSetting.view_raw_email_allowed_groups = "trust_level_0"

        get "/posts/#{post.id}/raw-email.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["raw_email"]).to eq("email_content")
      end

      it "can view raw email" do
        sign_in(moderator)

        get "/posts/#{post.id}/raw-email.json"
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["raw_email"]).to eq("email_content")
      end
    end
  end

  describe "#locked" do
    before { sign_in(moderator) }

    it "can lock and unlock the post" do
      put "/posts/#{public_post.id}/locked.json", params: { locked: "true" }
      expect(response.status).to eq(200)
      public_post.reload
      expect(public_post).to be_locked

      put "/posts/#{public_post.id}/locked.json", params: { locked: "false" }
      expect(response.status).to eq(200)
      public_post.reload
      expect(public_post).not_to be_locked
    end
  end

  describe "#notice" do
    it "can create and remove notices as a moderator" do
      sign_in(moderator)

      raw_notice = "Hello *world*!\n\nhttps://github.com/discourse/discourse"
      put "/posts/#{public_post.id}/notice.json", params: { notice: raw_notice }

      expect(response.status).to eq(200)
      expect(public_post.reload.custom_fields[Post::NOTICE]).to eq(
        "type" => Post.notices[:custom],
        "raw" => raw_notice,
        "cooked" => PrettyText.cook(raw_notice, features: { onebox: false }),
      )
      expect(UserHistory.where(action: UserHistory.actions[:post_staff_note_create]).count).to eq(1)

      put "/posts/#{public_post.id}/notice.json", params: { notice: nil }

      expect(response.status).to eq(200)
      expect(public_post.reload.custom_fields[Post::NOTICE]).to eq(nil)
      expect(UserHistory.where(action: UserHistory.actions[:post_staff_note_destroy]).count).to eq(
        1,
      )
    end

    describe "group moderators" do
      fab!(:group_user)
      let(:user) { group_user.user }
      let(:group) { group_user.group }

      before do
        SiteSetting.enable_category_group_moderation = true
        Fabricate(:category_moderation_group, category: topic.category, group:)

        sign_in(user)
      end

      it "can create and remove notices as a group moderator" do
        raw_notice = "Hello *world*!\n\nhttps://github.com/discourse/discourse"
        put "/posts/#{public_post.id}/notice.json", params: { notice: raw_notice }

        expect(response.status).to eq(200)
        expect(public_post.reload.custom_fields[Post::NOTICE]).to eq(
          "type" => Post.notices[:custom],
          "raw" => raw_notice,
          "cooked" => PrettyText.cook(raw_notice, features: { onebox: false }),
        )

        put "/posts/#{public_post.id}/notice.json", params: { notice: nil }

        expect(response.status).to eq(200)
        expect(public_post.reload.custom_fields[Post::NOTICE]).to eq(nil)
      end

      it "prevents a group moderator from altering notes outside of their category" do
        topic.category.category_moderation_groups.where(group:).delete_all

        put "/posts/#{public_post.id}/notice.json", params: { notice: "Hello" }

        expect(response.status).to eq(404)
      end

      it "prevents a normal user from altering notes" do
        group_user.destroy!
        put "/posts/#{public_post.id}/notice.json", params: { notice: "Hello" }

        expect(response.status).to eq(404)
      end
    end
  end

  describe "#pending" do
    subject(:request) { get "/posts/#{user.username}/pending.json" }

    context "when user is not logged in" do
      it_behaves_like "action requires login", :get, "/posts/system/pending.json"
    end

    context "when user is logged in" do
      let(:pending_posts) { response.parsed_body["pending_posts"] }

      before { sign_in(current_user) }

      context "when current user is the same as user" do
        let(:current_user) { user }

        context "when there are existing pending posts" do
          let!(:owner_pending_posts) do
            Fabricate.times(2, :reviewable_queued_post, created_by: user)
          end
          let!(:other_pending_post) { Fabricate(:reviewable_queued_post) }
          let(:expected_keys) do
            %w[
              avatar_template
              category_id
              created_at
              created_by_id
              name
              raw_text
              title
              topic_id
              topic_url
              username
            ]
          end

          it "returns user's pending posts" do
            request
            expect(pending_posts).to all include "id" => be_in(owner_pending_posts.map(&:id))
            expect(pending_posts).to all include(*expected_keys)
          end
        end

        context "when there aren't any pending posts" do
          it "returns an empty array" do
            request
            expect(pending_posts).to be_empty
          end
        end
      end

      context "when current user is a staff member" do
        let(:current_user) { moderator }

        context "when there are existing pending posts" do
          let!(:owner_pending_posts) do
            Fabricate.times(2, :reviewable_queued_post, created_by: user)
          end
          let!(:other_pending_post) { Fabricate(:reviewable_queued_post) }
          let(:expected_keys) do
            %w[
              avatar_template
              category_id
              created_at
              created_by_id
              name
              raw_text
              title
              topic_id
              topic_url
              username
            ]
          end

          it "returns user's pending posts" do
            request
            expect(pending_posts).to all include "id" => be_in(owner_pending_posts.map(&:id))
            expect(pending_posts).to all include(*expected_keys)
          end
        end

        context "when there aren't any pending posts" do
          it "returns an empty array" do
            request
            expect(pending_posts).to be_empty
          end
        end
      end

      context "when current user is another user" do
        let(:current_user) { Fabricate(:user) }

        it "does not allow access" do
          request
          expect(response).to have_http_status :not_found
        end
      end
    end
  end

  describe Plugin::Instance do
    describe "#add_permitted_post_create_param" do
      fab!(:user)
      let(:instance) { Plugin::Instance.new }
      let(:request) do
        Proc.new do
          post "/posts.json",
               params: {
                 raw: "this is the test content",
                 title: "this is the test title for the topic",
                 composer_open_duration_msecs: 204,
                 typing_duration_msecs: 100,
                 reply_to_post_number: 123,
                 string_arg: "123",
                 hash_arg: {
                   key1: "val",
                 },
                 array_arg: %w[1 2 3],
               }
        end
      end

      before do
        sign_in(user)
        SiteSetting.min_first_post_typing_time = 0
      end

      it "allows strings to be added" do
        request.call
        expect(@controller.send(:create_params)).not_to include(string_arg: "123")

        instance.add_permitted_post_create_param(:string_arg)
        request.call
        expect(@controller.send(:create_params)).to include(string_arg: "123")
      end

      it "allows hashes to be added" do
        instance.add_permitted_post_create_param(:hash_arg)
        request.call
        expect(@controller.send(:create_params)).not_to include(hash_arg: { key1: "val" })

        instance.add_permitted_post_create_param(:hash_arg, :hash)
        request.call
        expect(@controller.send(:create_params)).to include(hash_arg: { key1: "val" })
      end

      it "allows strings to be added" do
        instance.add_permitted_post_create_param(:array_arg)
        request.call
        expect(@controller.send(:create_params)).not_to include(array_arg: %w[1 2 3])

        instance.add_permitted_post_create_param(:array_arg, :array)
        request.call
        expect(@controller.send(:create_params)).to include(array_arg: %w[1 2 3])
      end
    end
  end
end
