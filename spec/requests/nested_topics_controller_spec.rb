# frozen_string_literal: true

RSpec.describe NestedTopicsController, type: :request do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user, post_number: 1) }

  before { SiteSetting.nested_replies_enabled = true }

  def roots_url(topic, page: 0, sort: "top")
    "/n/#{topic.slug}/#{topic.id}/roots.json?page=#{page}&sort=#{sort}"
  end

  def children_url(topic, post_number, page: 0, sort: "top", depth: 1)
    "/n/#{topic.slug}/#{topic.id}/children/#{post_number}.json?page=#{page}&sort=#{sort}&depth=#{depth}"
  end

  def context_url(topic, post_number, sort: "top", context: nil)
    url = "/n/#{topic.slug}/#{topic.id}/context/#{post_number}.json?sort=#{sort}"
    url += "&context=#{context}" if context
    url
  end

  describe "GET roots" do
    it "returns 404 when plugin is disabled" do
      SiteSetting.nested_replies_enabled = false
      sign_in(user)
      get roots_url(topic)
      expect(response.status).to eq(404)
    end

    it "returns 403 for anonymous users on private topics" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)
      get roots_url(private_topic)
      expect(response.status).to eq(403)
    end

    it "returns topic metadata and OP on initial load (page 0)" do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get roots_url(topic, page: 0)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).to have_key("topic")
      expect(json).to have_key("op_post")
      expect(json).to have_key("sort")
      expect(json).to have_key("message_bus_last_id")
      expect(json["roots"].length).to eq(2)
      expect(json["page"]).to eq(0)
    end

    it "does not include topic metadata on subsequent pages" do
      25.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }
      sign_in(user)

      get roots_url(topic, page: 1)
      expect(response.status).to eq(200)

      json = response.parsed_body
      expect(json).not_to have_key("topic")
      expect(json).not_to have_key("op_post")
      expect(json["page"]).to eq(1)
    end

    it "paginates with has_more_roots" do
      20.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }
      sign_in(user)

      get roots_url(topic, page: 0)
      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(true)
      expect(json["roots"].length).to eq(20)
    end

    it "returns has_more_roots false on last page" do
      5.times { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }
      sign_in(user)

      get roots_url(topic, page: 0)
      json = response.parsed_body
      expect(json["has_more_roots"]).to eq(false)
    end

    it "validates sort parameter and falls back to default" do
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get roots_url(topic, sort: "invalid")
      expect(response.status).to eq(200)
      json = response.parsed_body
      expect(json["sort"]).to eq(SiteSetting.nested_replies_default_sort)
    end

    it "uses site setting default when no sort param is provided" do
      SiteSetting.nested_replies_default_sort = "old"
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get "/n/#{topic.slug}/#{topic.id}/roots.json"
      json = response.parsed_body
      expect(json["sort"]).to eq("old")
    end

    it "sorts by top (like_count desc)" do
      low = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 1)
      high = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)
      sign_in(user)

      get roots_url(topic, sort: "top")
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

      get roots_url(topic, sort: "new")
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).to eq([new_post.id, old_post.id])
    end

    it "sorts by old (post_number asc)" do
      first = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      second = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      sign_in(user)

      get roots_url(topic, sort: "old")
      json = response.parsed_body
      root_ids = json["roots"].map { |r| r["id"] }
      expect(root_ids).to eq([first.id, second.id])
    end

    it "preloads children in the response" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get roots_url(topic, sort: "top")
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

      get roots_url(topic, sort: "top")
      json = response.parsed_body
      children_ids = json["roots"].first["children"].map { |c| c["id"] }
      expect(children_ids).to eq([high_child.id, low_child.id])

      get roots_url(topic, sort: "old")
      json = response.parsed_body
      children_ids = json["roots"].first["children"].map { |c| c["id"] }
      expect(children_ids).to eq([low_child.id, high_child.id])
    end

    it "includes direct_reply_count and total_descendant_count" do
      root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
      Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
      sign_in(user)

      get roots_url(topic)
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

        get roots_url(topic)
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

        get roots_url(topic)
        json = response.parsed_body
        root_json = json["roots"].find { |r| r["id"] == root.id }
        expect(root_json["children"]).to be_an(Array)
        expect(root_json["children"].length).to eq(1)
        expect(root_json["children"].first["id"]).to eq(child.id)
      end

      it "shows deleted root as placeholder for staff too" do
        root = Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil)
        root.update!(deleted_at: Time.current)
        sign_in(admin)

        get roots_url(topic)
        json = response.parsed_body
        root_json = json["roots"].find { |r| r["id"] == root.id }
        expect(root_json).to be_present
        expect(root_json["deleted_post_placeholder"]).to eq(true)
        expect(root_json["cooked"]).to eq("")
      end
    end

    describe "pinned reply" do
      fab!(:low_post) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 1)
      end
      fab!(:high_post) do
        Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)
      end

      before { @nested_topic_record = NestedTopic.create!(topic: topic) }

      def pin_post(post_number)
        @nested_topic_record.update!(pinned_post_number: post_number)
      end

      it "places the pinned reply first regardless of sort" do
        pin_post(low_post.post_number)
        sign_in(user)

        get roots_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(low_post.id)
        expect(json["pinned_post_number"]).to eq(low_post.post_number)
      end

      it "does not include pinned_post_number when no reply is pinned" do
        sign_in(user)

        get roots_url(topic, sort: "top")

        json = response.parsed_body
        expect(json).not_to have_key("pinned_post_number")
      end

      it "fetches the pinned reply even when it would be on a later page" do
        19.times do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 5)
        end
        pin_post(low_post.post_number)
        sign_in(user)

        get roots_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(low_post.id)
      end

      it "does not promote a deleted post to pinned position" do
        low_post.update!(deleted_at: Time.current)
        pin_post(low_post.post_number)
        sign_in(user)

        get roots_url(topic, sort: "top")

        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).not_to eq(low_post.id)
      end

      it "ignores a pinned post_number that does not exist" do
        pin_post(99_999)
        sign_in(user)

        get roots_url(topic, sort: "top")

        json = response.parsed_body
        expect(response.status).to eq(200)
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(high_post.id)
      end

      it "does not pin on subsequent pages" do
        25.times do
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 5)
        end
        pin_post(low_post.post_number)
        sign_in(user)

        get roots_url(topic, page: 1, sort: "top")

        json = response.parsed_body
        expect(json).not_to have_key("pinned_post_number")
      end
    end

    describe "PUT pin" do
      fab!(:root_post) { Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil) }

      before { NestedTopic.create!(topic: topic) }

      def pin_url(topic)
        "/n/#{topic.slug}/#{topic.id}/pin.json"
      end

      it "returns 403 for non-staff users" do
        sign_in(user)
        put pin_url(topic), params: { post_number: root_post.post_number }
        expect(response.status).to eq(403)
      end

      it "allows staff to pin a post" do
        sign_in(admin)
        put pin_url(topic), params: { post_number: root_post.post_number }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["pinned_post_number"]).to eq(root_post.post_number)

        topic.reload
        expect(topic.nested_topic&.pinned_post_number).to eq(root_post.post_number)
      end

      it "allows staff to unpin a post" do
        topic.reload.nested_topic.update!(pinned_post_number: root_post.post_number)

        sign_in(admin)
        put pin_url(topic), params: { post_number: nil }
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["pinned_post_number"]).to be_nil

        topic.reload
        expect(topic.nested_topic&.pinned_post_number).to be_nil
      end

      it "returns 404 for a nonexistent post_number" do
        sign_in(admin)
        put pin_url(topic), params: { post_number: 99_999 }
        expect(response.status).to eq(404)
      end

      it "returns 400 when pinning a non-root post" do
        child_post =
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: root_post.post_number)

        sign_in(admin)
        put pin_url(topic), params: { post_number: child_post.post_number }
        expect(response.status).to eq(400)
      end

      it "persists the pin so that roots returns it first" do
        high_post =
          Fabricate(:post, topic: topic, user: user, reply_to_post_number: nil, like_count: 10)

        sign_in(admin)
        put pin_url(topic), params: { post_number: root_post.post_number }
        expect(response.status).to eq(200)

        get roots_url(topic, sort: "top")
        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids.first).to eq(root_post.id)
        expect(json["pinned_post_number"]).to eq(root_post.post_number)
      end

      it "lazily creates a NestedTopic record when nested_replies_default is on" do
        topic.nested_topic.destroy!
        SiteSetting.nested_replies_default = true

        sign_in(admin)
        put pin_url(topic), params: { post_number: root_post.post_number }
        expect(response.status).to eq(200)

        topic.reload
        expect(topic.nested_topic).to be_present
        expect(topic.nested_topic.pinned_post_number).to eq(root_post.post_number)
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
        get roots_url(topic)
        json = response.parsed_body
        root_ids = json["roots"].map { |r| r["id"] }
        expect(root_ids).not_to include(whisper.id)
      end

      it "includes whispers for staff" do
        sign_in(admin)
        get roots_url(topic)
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

        get roots_url(topic)
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

        get roots_url(topic)
        json = response.parsed_body
        root_json = json["roots"].find { |r| r["id"] == root.id }
        expect(root_json["direct_reply_count"]).to eq(2)
        expect(root_json["total_descendant_count"]).to eq(2)
      end
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

      it "shows deleted child as placeholder for staff too" do
        child = Fabricate(:post, topic: topic, user: user, reply_to_post_number: root.post_number)
        child.update!(deleted_at: Time.current)
        sign_in(admin)

        get children_url(topic, root.post_number)
        json = response.parsed_body
        child_json = json["children"].find { |c| c["id"] == child.id }
        expect(child_json).to be_present
        expect(child_json["deleted_post_placeholder"]).to eq(true)
        expect(child_json["cooked"]).to eq("")
      end
    end

    it "returns 404 when plugin is disabled" do
      SiteSetting.nested_replies_enabled = false
      sign_in(user)
      get children_url(topic, root.post_number)
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

    it "returns 403 for unauthorized topic" do
      private_category = Fabricate(:private_category, group: Fabricate(:group))
      private_topic = Fabricate(:topic, category: private_category)
      Fabricate(:post, topic: private_topic, post_number: 1)
      root = Fabricate(:post, topic: private_topic, reply_to_post_number: nil)
      sign_in(user)
      get context_url(private_topic, root.post_number)
      expect(response.status).to eq(403)
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

    it "allows staff to enable nested view" do
      sign_in(admin)
      put toggle_url(topic), params: { enabled: true }
      expect(response.status).to eq(200)
      expect(response.parsed_body["is_nested_view"]).to eq(true)

      topic.reload
      expect(topic.reload.nested_topic).to be_present
    end

    it "allows staff to disable nested view" do
      NestedTopic.create!(topic: topic)

      sign_in(admin)
      put toggle_url(topic), params: { enabled: false }
      expect(response.status).to eq(200)
      expect(response.parsed_body["is_nested_view"]).to eq(false)

      topic.reload
      expect(topic.reload.nested_topic).to be_nil
    end
  end
end
