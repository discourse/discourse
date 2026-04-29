# frozen_string_literal: true

RSpec.describe NestedTopicsController, type: :request do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  before { SiteSetting.nested_replies_enabled = true }

  def show_url(topic, page: 0, sort: "top")
    "/n/#{topic.slug}/#{topic.id}.json?page=#{page}&sort=#{sort}"
  end

  def children_url(topic, post_number, page: 0, sort: "top", depth: 1)
    "/n/#{topic.slug}/#{topic.id}/children/#{post_number}.json?page=#{page}&sort=#{sort}&depth=#{depth}"
  end

  def context_url(topic, post_number, sort: "top", context: nil)
    url = "/n/#{topic.slug}/#{topic.id}/context/#{post_number}.json?sort=#{sort}"
    url += "&context=#{context}" if context
    url
  end

  describe "GET respond" do
    it "redirects crawlers to the flat topic view" do
      get "/n/#{topic.slug}/#{topic.id}", headers: { "HTTP_USER_AGENT" => "Googlebot" }

      expect(response).to redirect_to("/t/#{topic.slug}/#{topic.id}")
      expect(response.status).to eq(301)
    end

    it "redirects crawlers to the flat topic view with post number" do
      get "/n/#{topic.slug}/#{topic.id}/5", headers: { "HTTP_USER_AGENT" => "Googlebot" }

      expect(response).to redirect_to("/t/#{topic.slug}/#{topic.id}/5")
      expect(response.status).to eq(301)
    end

    it "returns 404 for anonymous users on private topics" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)

      get "/n/#{private_topic.slug}/#{private_topic.id}"
      expect(response.status).to eq(404)
    end

    it "redirects private messages to flat view" do
      pm = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, topic: pm, user: user, post_number: 1)

      sign_in(user)
      get "/n/#{pm.slug}/#{pm.id}"

      expect(response).to redirect_to("/t/#{pm.slug}/#{pm.id}")
      expect(response.status).to eq(302)
    end

    it "redirects private messages to flat view with post number" do
      pm = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, topic: pm, user: user, post_number: 1)

      sign_in(user)
      get "/n/#{pm.slug}/#{pm.id}/5"

      expect(response).to redirect_to("/t/#{pm.slug}/#{pm.id}/5")
      expect(response.status).to eq(302)
    end
  end

  describe "GET show" do
    it "returns 404 when plugin is disabled" do
      SiteSetting.nested_replies_enabled = false
      sign_in(user)
      get show_url(topic)
      expect(response.status).to eq(404)
    end

    it "redirects private messages to flat view" do
      pm = Fabricate(:private_message_topic, user: user)
      Fabricate(:post, topic: pm, user: user, post_number: 1)

      sign_in(user)
      get show_url(pm)

      expect(response).to redirect_to("/t/#{pm.slug}/#{pm.id}")
    end

    it "returns 404 for anonymous users on private topics" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)
      get show_url(private_topic)
      expect(response.status).to eq(404)
    end

    it "returns 404 for signed-in users who cannot see the topic" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)
      sign_in(user)
      get show_url(private_topic)
      expect(response.status).to eq(404)
    end

    it "returns topic metadata and OP on initial load (page 0)" do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get show_url(topic, page: 0)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to have_key("topic")
      expect(json).to have_key("op_post")
      expect(json).to have_key("sort")
      expect(json).to have_key("message_bus_last_id")
      expect(json["roots"].length).to eq(2)
      expect(json["page"]).to eq(0)
    end

    it "piggybacks suggested topics at the top level when the first page is the last page" do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      suggested = Fabricate(:post).topic
      sign_in(user)

      get show_url(topic, page: 0)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(false)
      expect(json["topic"]).not_to have_key("suggested_topics")
      expect(json).to have_key("suggested_topics")
      expect(json["suggested_topics"].map { |t| t["id"] }).to include(suggested.id)
    end

    it "omits suggested topics on page 0 when there are more pages to load" do
      (NestedReplies::TreeLoader::ROOTS_PER_PAGE + 1).times do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      end
      Fabricate(:post).topic
      sign_in(user)

      get show_url(topic, page: 0)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(true)
      expect(json).not_to have_key("suggested_topics")
      expect(json["topic"]).not_to have_key("suggested_topics")
    end

    it "piggybacks suggested topics on the final loadMore page" do
      (NestedReplies::TreeLoader::ROOTS_PER_PAGE + 1).times do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      end
      suggested = Fabricate(:post).topic
      sign_in(user)

      get show_url(topic, page: 1)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(false)
      expect(json).not_to have_key("topic")
      expect(json).to have_key("suggested_topics")
      expect(json["suggested_topics"].map { |t| t["id"] }).to include(suggested.id)
    end

    it "does not include topic metadata on subsequent pages" do
      25.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }
      sign_in(user)

      get show_url(topic, page: 1)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).not_to have_key("topic")
      expect(json).not_to have_key("op_post")
      expect(json["page"]).to eq(1)
    end

    it "paginates with has_more_roots" do
      NestedReplies::TreeLoader::ROOTS_PER_PAGE.times do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      end
      sign_in(user)

      get show_url(topic, page: 0)
      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(true)
      expect(json["roots"].length).to eq(NestedReplies::TreeLoader::ROOTS_PER_PAGE)
    end

    it "returns has_more_roots false on last page" do
      5.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }
      sign_in(user)

      get show_url(topic, page: 0)
      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(false)
    end

    it "validates sort parameter and falls back to default" do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get show_url(topic, sort: "invalid")
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["sort"]).to eq(SiteSetting.nested_replies_default_sort)
    end

    it "uses site setting default when no sort param is provided" do
      SiteSetting.nested_replies_default_sort = "old"
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get "/n/#{topic.slug}/#{topic.id}.json"
      json = response.parsed_body
      expect(json["sort"]).to eq("old")
    end

    it "sorts by top (like_count desc)" do
      low = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 1)
      high = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)
      sign_in(user)

      get show_url(topic, sort: "top")
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).to eq([high.id, low.id])
    end

    it "sorts by new (created_at desc)" do
      old_post =
        Fabricate(
          :post,
          topic: topic,
          user: user,
          reply_to_post_number: nil,
          created_at: 2.days.ago,
        )
      new_post =
        Fabricate(
          :post,
          topic: topic,
          user: user,
          reply_to_post_number: nil,
          created_at: 1.hour.ago,
        )
      sign_in(user)

      get show_url(topic, sort: "new")
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).to eq([new_post.id, old_post.id])
    end

    it "sorts by old (post_number asc)" do
      first = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      second = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get show_url(topic, sort: "old")
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).to eq([first.id, second.id])
    end

    it "preloads children in the response" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get show_url(topic, sort: "top")
      json = response.parsed_body
      root_json = json["roots"].first
      expect(root_json["children"]).to be_an(Array)
      expect(root_json["children"].length).to eq(1)
      expect(root_json["children"].first["id"]).to eq(child.id)
    end

    it "sorts preloaded children consistently with roots" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      low_child =
        Fabricate(
          :post,
          topic: topic,
          user: user,
          reply_to_post_number: root.post_number,
          like_count: 1,
        )
      high_child =
        Fabricate(
          :post,
          topic: topic,
          user: user,
          reply_to_post_number: root.post_number,
          like_count: 10,
        )
      sign_in(user)

      get show_url(topic, sort: "top")
      json = response.parsed_body
      children_ids = json["roots"].first["children"].map { |c| c["id"] }
      expect(children_ids).to eq([high_child.id, low_child.id])

      get show_url(topic, sort: "old")
      json = response.parsed_body
      children_ids = json["roots"].first["children"].map { |c| c["id"] }
      expect(children_ids).to eq([low_child.id, high_child.id])
    end

    it "includes direct_reply_count and total_descendant_count" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get show_url(topic)
      json = response.parsed_body
      root_json = json["roots"].first
      expect(root_json).to have_key("direct_reply_count")
      expect(root_json["direct_reply_count"]).to eq(1)
    end

    describe "deleted post placeholders" do
      it "shows deleted root as placeholder for non-staff" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        root.update!(deleted_at: Time.current)
        sign_in(user)

        get show_url(topic)
        json = response.parsed_body
        root_json = json["roots"].find { |r| r["id"] == root.id }
        expect(root_json).to be_present
        expect(root_json["deleted_post_placeholder"]).to eq(true)
        expect(root_json["cooked"]).to eq("")
        expect(root_json["raw"]).to be_nil
        expect(root_json["actions_summary"]).to eq([])
      end

      it "preserves children under deleted root for non-staff" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        root.update!(deleted_at: Time.current)
        sign_in(user)

        get show_url(topic)
        json = response.parsed_body
        root_json = json["roots"].find { |r| r["id"] == root.id }
        expect(root_json["children"]).to be_an(Array)
        expect(root_json["children"].length).to eq(1)
        expect(root_json["children"].first["id"]).to eq(child.id)
      end

      it "shows deleted root as placeholder for staff but preserves content" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        root.update!(deleted_at: Time.current)
        sign_in(admin)

        get show_url(topic)
        json = response.parsed_body
        root_json = json["roots"].find { |r| r["id"] == root.id }
        expect(root_json).to be_present
        expect(root_json["deleted_post_placeholder"]).to eq(true)
        expect(root_json["cooked"]).to be_present
        expect(root_json["cooked"]).not_to eq("")
      end
    end

    describe "pinned replies" do
      fab!(:low_post) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 1)
      end
      fab!(:high_post) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)
      end

      fab!(:nested_topic_record) { Fabricate(:nested_topic, topic: topic) }

      def pin_posts(*posts)
        nested_topic_record.update!(pinned_post_ids: posts.map(&:id))
      end

      it "places pinned replies first regardless of sort" do
        pin_posts(low_post)
        sign_in(user)

        get show_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(low_post.id)
        expect(json["pinned_post_ids"]).to contain_exactly(low_post.id)
      end

      it "does not include pinned_post_ids when none are pinned" do
        sign_in(user)

        get show_url(topic, sort: "top")

        json = response.parsed_body
        expect(json).not_to have_key("pinned_post_ids")
      end

      it "fetches a pinned reply even when it would be on a later page" do
        19.times do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 5)
        end
        pin_posts(low_post)
        sign_in(user)

        get show_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(low_post.id)
      end

      it "does not promote a deleted post to pinned position" do
        low_post.update!(deleted_at: Time.current)
        pin_posts(low_post)
        sign_in(user)

        get show_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).not_to eq(low_post.id)
      end

      it "ignores a pinned post_id that does not exist" do
        nested_topic_record.update!(pinned_post_ids: [99_999])
        sign_in(user)

        get show_url(topic, sort: "top")

        json = response.parsed_body
        expect(response.status).to eq(200)
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(high_post.id)
      end

      it "does not pin on subsequent pages" do
        25.times do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 5)
        end
        pin_posts(low_post)
        sign_in(user)

        get show_url(topic, page: 1, sort: "top")

        json = response.parsed_body
        expect(json).not_to have_key("pinned_post_ids")
      end

      it "places multiple pinned replies first in pin order" do
        pin_posts(low_post, high_post)
        sign_in(user)

        get show_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids[0]).to eq(low_post.id)
        expect(root_ids[1]).to eq(high_post.id)
      end
    end
  end

  describe "PUT pin" do
    fab!(:root_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }

    before { Fabricate(:nested_topic, topic: topic) }

    def pin_url(topic)
      "/n/#{topic.slug}/#{topic.id}/pin.json"
    end

    it "returns 403 for non-staff users" do
      sign_in(user)
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(403)
    end

    it "allows moderators to pin a post" do
      sign_in(Fabricate(:moderator))
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(200)
      expect(response.parsed_body["pinned_post_ids"]).to contain_exactly(root_post.id)
    end

    it "allows staff to pin a post" do
      sign_in(admin)
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["pinned_post_ids"]).to contain_exactly(root_post.id)

      topic.reload
      expect(topic.nested_topic.pinned_post_ids).to contain_exactly(root_post.id)
    end

    it "allows staff to unpin a post by toggling" do
      topic.reload.nested_topic.update!(pinned_post_ids: [root_post.id])

      sign_in(admin)
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["pinned_post_ids"]).to eq([])

      topic.reload
      expect(topic.nested_topic.pinned_post_ids).to eq([])
    end

    it "returns 404 for a nonexistent post_id" do
      sign_in(admin)
      put pin_url(topic), params: { post_id: 99_999 }
      expect(response.status).to eq(404)
    end

    it "returns 404 when no post_id is provided" do
      sign_in(admin)
      put pin_url(topic)
      expect(response.status).to eq(404)
    end

    it "returns 400 when pinning a non-root post" do
      child_post =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: root_post.post_number)

      sign_in(admin)
      put pin_url(topic), params: { post_id: child_post.id }
      expect(response.status).to eq(400)
    end

    it "persists the pin so that roots returns it first" do
      high_post =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)

      sign_in(admin)
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(200)

      get show_url(topic, sort: "top")
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids.first).to eq(root_post.id)
      expect(json["pinned_post_ids"]).to contain_exactly(root_post.id)
    end

    it "allows pinning multiple posts" do
      second_root =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)

      sign_in(admin)
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(200)

      put pin_url(topic), params: { post_id: second_root.id }
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["pinned_post_ids"]).to contain_exactly(root_post.id, second_root.id)
    end

    it "rejects pinning when 10 posts are already pinned" do
      posts = 10.times.map { Fabricate(:post, topic: topic, reply_to_post_number: nil) }
      topic.nested_topic.update!(pinned_post_ids: posts.map(&:id))

      extra = Fabricate(:post, topic: topic, reply_to_post_number: nil)
      sign_in(admin)
      put pin_url(topic), params: { post_id: extra.id }
      expect(response.status).to eq(400)
    end

    it "lazily creates a NestedTopic record when nested_replies_default is on" do
      topic.nested_topic.destroy!
      SiteSetting.nested_replies_default = true

      sign_in(admin)
      put pin_url(topic), params: { post_id: root_post.id }
      expect(response.status).to eq(200)

      topic.reload
      expect(topic.nested_topic).to be_present
      expect(topic.nested_topic.pinned_post_ids).to contain_exactly(root_post.id)
    end
  end

  describe "whisper visibility" do
    before { SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}" }

    fab!(:whisper) do
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        reply_to_post_number: nil,
        post_type: Post.types[:whisper],
      )
    end

    it "excludes whispers for regular users" do
      sign_in(user)
      get show_url(topic)
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).not_to include(whisper.id)
    end

    it "includes whispers for staff" do
      sign_in(admin)
      get show_url(topic)
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).to include(whisper.id)
    end

    it "excludes whisper children for regular users" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      whisper_child =
        Fabricate(
          :post,
          topic: topic,
          user: admin,
          reply_to_post_number: root.post_number,
          post_type: Post.types[:whisper],
        )
      sign_in(user)

      get children_url(topic, root.post_number)
      json = response.parsed_body
      child_ids = json["children"].map { |c| c["id"] }
      expect(child_ids).not_to include(whisper_child.id)
    end

    it "includes whisper children for staff" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      whisper_child =
        Fabricate(
          :post,
          topic: topic,
          user: admin,
          reply_to_post_number: root.post_number,
          post_type: Post.types[:whisper],
        )
      sign_in(admin)

      get children_url(topic, root.post_number)
      json = response.parsed_body
      child_ids = json["children"].map { |c| c["id"] }
      expect(child_ids).to include(whisper_child.id)
    end
  end

  describe "whisper reply count visibility" do
    before { SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}" }

    it "excludes whisper from reply counts for regular users" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        reply_to_post_number: root.post_number,
        post_type: Post.types[:whisper],
      )
      sign_in(user)

      get show_url(topic)
      json = response.parsed_body
      root_json = json["roots"].find { |r| r["id"] == root.id }
      expect(root_json["direct_reply_count"]).to eq(1)
      expect(root_json["total_descendant_count"]).to eq(1)
    end

    it "includes whisper in reply counts for staff" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      Fabricate(
        :post,
        topic: topic,
        user: admin,
        reply_to_post_number: root.post_number,
        post_type: Post.types[:whisper],
      )
      sign_in(admin)

      get show_url(topic)
      json = response.parsed_body
      root_json = json["roots"].find { |r| r["id"] == root.id }
      expect(root_json["direct_reply_count"]).to eq(2)
      expect(root_json["total_descendant_count"]).to eq(2)
    end
  end

  describe "GET children" do
    fab!(:root) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }

    it "returns children of a post" do
      child1 = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      child2 = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get children_url(topic, root.post_number)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json["children"].length).to eq(2)
      expect(json["page"]).to eq(0)
    end

    it "paginates children" do
      50.times do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      end
      sign_in(user)

      get children_url(topic, root.post_number, page: 0)
      json = response.parsed_body
      expect(json["has_more"]).to eq(true)
      expect(json["children"].length).to eq(50)
    end

    it "returns has_more false when fewer than page size" do
      3.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number) }
      sign_in(user)

      get children_url(topic, root.post_number)
      json = response.parsed_body
      expect(json["has_more"]).to eq(false)
    end

    describe "sorting" do
      it "sorts children by top (like_count desc)" do
        low =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: root.post_number,
            like_count: 1,
          )
        high =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: root.post_number,
            like_count: 10,
          )
        sign_in(user)

        get children_url(topic, root.post_number, sort: "top")
        json = response.parsed_body
        child_ids = json["children"].map { |c| c["id"] }
        expect(child_ids).to eq([high.id, low.id])
      end

      it "sorts children by new (created_at desc)" do
        old_child =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: root.post_number,
            created_at: 2.days.ago,
          )
        new_child =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: root.post_number,
            created_at: 1.hour.ago,
          )
        sign_in(user)

        get children_url(topic, root.post_number, sort: "new")
        json = response.parsed_body
        child_ids = json["children"].map { |c| c["id"] }
        expect(child_ids).to eq([new_child.id, old_child.id])
      end

      it "sorts children by old (post_number asc)" do
        first = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        second = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        sign_in(user)

        get children_url(topic, root.post_number, sort: "old")
        json = response.parsed_body
        child_ids = json["children"].map { |c| c["id"] }
        expect(child_ids).to eq([first.id, second.id])
      end

      it "respects sort at max nesting depth" do
        SiteSetting.nested_replies_max_depth = 2
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        low_grandchild =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: child.post_number,
            like_count: 1,
          )
        high_grandchild =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: child.post_number,
            like_count: 10,
          )
        sign_in(user)

        get children_url(topic, child.post_number, sort: "top", depth: 2)
        json = response.parsed_body
        child_ids = json["children"].map { |c| c["id"] }
        expect(child_ids).to eq([high_grandchild.id, low_grandchild.id])
      end

      it "sorts flattened descendants when cap is enabled" do
        SiteSetting.nested_replies_cap_nesting_depth = true
        SiteSetting.nested_replies_max_depth = 2
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        low_gc =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: child.post_number,
            like_count: 1,
          )
        high_gc =
          Fabricate(
            :post,
            topic: topic,
            user: user,
            reply_to_post_number: child.post_number,
            like_count: 10,
          )
        sign_in(user)

        get children_url(topic, child.post_number, sort: "top", depth: 2)
        json = response.parsed_body
        child_ids = json["children"].map { |c| c["id"] }
        expect(child_ids).to eq([high_gc.id, low_gc.id])
      end
    end

    it "flattens descendants at max depth when cap is enabled" do
      SiteSetting.nested_replies_cap_nesting_depth = true
      SiteSetting.nested_replies_max_depth = 2
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      grandchild =
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)
      sign_in(user)

      get children_url(topic, child.post_number, depth: 2)
      json = response.parsed_body
      child_json = json["children"].find { |c| c["id"] == grandchild.id }
      expect(child_json).to be_present
      expect(child_json["children"]).to eq([])
    end

    it "paginates flattened descendants inside the CTE" do
      SiteSetting.nested_replies_cap_nesting_depth = true
      SiteSetting.nested_replies_max_depth = 2
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      grandchildren =
        3.times.map do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)
        end
      sign_in(user)

      stub_const(NestedReplies::TreeLoader, :CHILDREN_PER_PAGE, 2) do
        get children_url(topic, child.post_number, depth: 2, page: 0)
        page0 = response.parsed_body
        expect(page0["children"].length).to eq(2)
        expect(page0["has_more"]).to eq(true)

        get children_url(topic, child.post_number, depth: 2, page: 1)
        page1 = response.parsed_body
        expect(page1["children"].length).to eq(1)

        all_ids = page0["children"].map { |c| c["id"] } + page1["children"].map { |c| c["id"] }
        expect(all_ids).to match_array(grandchildren.map(&:id))
      end
    end

    describe "deleted post placeholders" do
      it "shows deleted child as placeholder for non-staff" do
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(user)

        get children_url(topic, root.post_number)
        json = response.parsed_body
        child_json = json["children"].find { |c| c["id"] == child.id }
        expect(child_json).to be_present
        expect(child_json["deleted_post_placeholder"]).to eq(true)
        expect(child_json["cooked"]).to eq("")
        expect(child_json["raw"]).to be_nil
        expect(child_json["actions_summary"]).to eq([])
      end

      it "preserves children of a deleted post" do
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        grandchild =
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(user)

        get children_url(topic, root.post_number)
        json = response.parsed_body
        child_json = json["children"].find { |c| c["id"] == child.id }
        expect(child_json).to be_present
        expect(child_json["deleted_post_placeholder"]).to eq(true)
        expect(child_json["children"]).to be_an(Array)
        expect(child_json["children"].length).to eq(1)
        expect(child_json["children"].first["id"]).to eq(grandchild.id)
      end

      it "shows deleted child as placeholder for staff but preserves content" do
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(admin)

        get children_url(topic, root.post_number)
        json = response.parsed_body
        child_json = json["children"].find { |c| c["id"] == child.id }
        expect(child_json).to be_present
        expect(child_json["deleted_post_placeholder"]).to eq(true)
        expect(child_json["cooked"]).to be_present
        expect(child_json["cooked"]).not_to eq("")
      end
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.nested_replies_enabled = false
      sign_in(user)
      get children_url(topic, root.post_number)
      expect(response.status).to eq(404)
    end

    it "returns 404 for unauthorized topic" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)
      private_root = Fabricate(:post, topic: private_topic, reply_to_post_number: nil)
      sign_in(user)
      get children_url(private_topic, private_root.post_number)
      expect(response.status).to eq(404)
    end
  end

  describe "GET context" do
    it "returns ancestor chain, target post, and siblings" do
      chain = [op]
      3.times do |i|
        reply_to = i == 0 ? nil : chain.last.post_number
        chain << Fabricate(
          :post,
          topic: topic,
          user: Fabricate(:user),
          reply_to_post_number: reply_to,
        )
      end
      target = chain.last
      sign_in(user)

      get context_url(topic, target.post_number)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to have_key("topic")
      expect(json).to have_key("op_post")
      expect(json).to have_key("ancestor_chain")
      expect(json).to have_key("siblings")
      expect(json).to have_key("target_post")
      expect(json).to have_key("message_bus_last_id")
    end

    it "returns empty ancestors when context=0" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get context_url(topic, child.post_number, context: 0)
      json = response.parsed_body
      expect(json["ancestor_chain"]).to be_empty
    end

    it "returns 404 for nonexistent post_number" do
      sign_in(user)
      get context_url(topic, 99_999)
      expect(response.status).to eq(404)
    end

    it "returns 404 when plugin disabled" do
      SiteSetting.nested_replies_enabled = false
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)
      get context_url(topic, root.post_number)
      expect(response.status).to eq(404)
    end

    it "returns 404 for unauthorized topic" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)
      root = Fabricate(:post, topic: private_topic, reply_to_post_number: nil)
      sign_in(user)
      get context_url(private_topic, root.post_number)
      expect(response.status).to eq(404)
    end

    it "includes target post children" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get context_url(topic, root.post_number)
      json = response.parsed_body
      expect(json["target_post"]["children"]).to be_an(Array)
      expect(json["target_post"]["children"].length).to eq(1)
    end

    describe "deleted post placeholders" do
      it "shows deleted ancestor as placeholder for non-staff" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        grandchild =
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(user)

        get context_url(topic, grandchild.post_number)
        json = response.parsed_body
        ancestor = json["ancestor_chain"].find { |a| a["id"] == child.id }
        expect(ancestor).to be_present
        expect(ancestor["deleted_post_placeholder"]).to eq(true)
        expect(ancestor["cooked"]).to eq("")
        expect(ancestor["raw"]).to be_nil
        expect(ancestor["actions_summary"]).to eq([])
      end

      it "preserves tree structure through deleted ancestors" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        grandchild =
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(user)

        get context_url(topic, grandchild.post_number)
        json = response.parsed_body
        expect(json["ancestor_chain"].map { |a| a["id"] }).to include(child.id)
        expect(json["target_post"]["id"]).to eq(grandchild.id)
      end

      it "shows deleted ancestor as placeholder for staff but preserves content" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        grandchild =
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: child.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(admin)

        get context_url(topic, grandchild.post_number)
        json = response.parsed_body
        ancestor = json["ancestor_chain"].find { |a| a["id"] == child.id }
        expect(ancestor).to be_present
        expect(ancestor["deleted_post_placeholder"]).to eq(true)
        expect(ancestor["cooked"]).to be_present
        expect(ancestor["cooked"]).not_to eq("")
      end
    end
  end

  describe "PUT toggle" do
    def toggle_url(topic)
      "/n/#{topic.slug}/#{topic.id}/toggle.json"
    end

    it "returns 403 for non-staff users" do
      sign_in(user)
      put toggle_url(topic), params: { enabled: true }
      expect(response.status).to eq(403)
    end

    it "allows moderators to toggle nested view" do
      sign_in(Fabricate(:moderator))
      put toggle_url(topic), params: { enabled: true }
      expect(response.status).to eq(200)
      expect(response.parsed_body["is_nested_view"]).to eq(true)
    end

    it "allows staff to enable nested view" do
      sign_in(admin)
      put toggle_url(topic), params: { enabled: true }
      expect(response.status).to eq(200)
      expect(response.parsed_body["is_nested_view"]).to eq(true)

      topic.reload
      expect(topic.reload.nested_topic).to be_present
    end

    it "allows staff to disable nested view" do
      Fabricate(:nested_topic, topic: topic)

      sign_in(admin)
      put toggle_url(topic), params: { enabled: false }
      expect(response.status).to eq(200)
      expect(response.parsed_body["is_nested_view"]).to eq(false)

      topic.reload
      expect(topic.reload.nested_topic).to be_nil
    end

    it "returns 404 for private messages" do
      pm = Fabricate(:private_message_topic, user: admin)
      Fabricate(:post, topic: pm, user: admin, post_number: 1)

      sign_in(admin)
      put toggle_url(pm), params: { enabled: true }
      expect(response.status).to eq(404)
    end
  end

  describe "visit tracking" do
    fab!(:root_reply) { Fabricate(:post, topic: topic, user: user) }

    it "tracks a visit on show" do
      sign_in(user)
      get show_url(topic), params: { track_visit: true }
      expect(response.status).to eq(200)

      Scheduler::Defer.do_all_work

      expect(TopicUser.find_by(topic: topic, user: user).first_visited_at).to be_present
      expect(TopicViewItem.exists?(topic_id: topic.id, user_id: user.id)).to eq(true)
    end

    it "tracks a visit on context" do
      sign_in(user)
      get context_url(topic, root_reply.post_number), params: { track_visit: true }
      expect(response.status).to eq(200)

      Scheduler::Defer.do_all_work

      expect(TopicUser.find_by(topic: topic, user: user).first_visited_at).to be_present
      expect(TopicViewItem.exists?(topic_id: topic.id, user_id: user.id)).to eq(true)
    end

    it "does not track a user visit for anonymous users" do
      topic_user_count = TopicUser.count

      get show_url(topic)
      expect(response.status).to eq(200)
      Scheduler::Defer.do_all_work

      expect(TopicUser.count).to eq(topic_user_count)
    end
  end

  describe "GET activity" do
    def activity_url(topic)
      "/n/#{topic.slug}/#{topic.id}/activity.json"
    end

    it "returns 404 when nested replies is disabled" do
      SiteSetting.nested_replies_enabled = false
      sign_in(user)
      get activity_url(topic)
      expect(response.status).to eq(404)
    end

    it "includes a synthetic topic_created entry first" do
      sign_in(user)
      get activity_url(topic)
      expect(response.status).to eq(200)

      actions = response.parsed_body["small_actions"]
      expect(actions.length).to eq(1)
      expect(actions[0]["action_code"]).to eq("topic_created")
      expect(actions[0]["username"]).to eq(user.username)
    end

    it "returns small action posts in chronological order after topic_created" do
      sign_in(user)

      topic.add_small_action(admin, "closed.enabled")
      topic.add_small_action(admin, "opened.enabled")
      topic.add_small_action(admin, "invited_user", "testuser")

      get activity_url(topic)
      expect(response.status).to eq(200)

      actions = response.parsed_body["small_actions"]
      expect(actions.length).to eq(4)
      expect(actions[0]["action_code"]).to eq("topic_created")
      expect(actions[1]["action_code"]).to eq("closed.enabled")
      expect(actions[2]["action_code"]).to eq("opened.enabled")
      expect(actions[3]["action_code"]).to eq("invited_user")
      expect(actions[3]["action_code_who"]).to eq("testuser")
      expect(actions[1]["username"]).to eq(admin.username)
    end

    it "excludes whisper action-code posts for non-whisperers" do
      topic.add_moderator_post(
        admin,
        nil,
        post_type: Post.types[:whisper],
        action_code: "assigned",
        custom_fields: {
          "action_code_who" => user.username,
        },
      )

      sign_in(user)
      get activity_url(topic)

      actions = response.parsed_body["small_actions"]
      expect(actions.map { |a| a["action_code"] }).not_to include("assigned")
    end

    it "includes whisper action-code posts for whisperers" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"

      topic.add_moderator_post(
        admin,
        nil,
        post_type: Post.types[:whisper],
        action_code: "assigned",
        custom_fields: {
          "action_code_who" => user.username,
        },
      )

      sign_in(admin)
      get activity_url(topic)

      actions = response.parsed_body["small_actions"]
      expect(actions.map { |a| a["action_code"] }).to include("assigned")
    end
  end
end
