# frozen_string_literal: true

RSpec.describe GroupsController do
  fab!(:user)
  fab!(:user2) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }
  let(:group) { Fabricate(:group, users: [user]) }
  let(:moderator_group_id) { Group::AUTO_GROUPS[:moderators] }
  fab!(:admin)
  fab!(:moderator)

  describe "#index" do
    let(:staff_group) do
      Fabricate(:group, name: "staff_group", visibility_level: Group.visibility_levels[:staff])
    end

    it "ensures that groups can be paginated" do
      50.times { Fabricate(:group) }

      get "/groups.json"

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["groups"].size).to eq(36)
      expect(body["total_rows_groups"]).to eq(50)
      expect(body["load_more_groups"]).to eq("/groups?page=1")

      get "/groups.json", params: { page: 1 }

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["groups"].size).to eq(14)
      expect(body["total_rows_groups"]).to eq(50)
      expect(body["load_more_groups"]).to eq("/groups?page=2")
    end

    it "only accepts valid page numbers" do
      get "/groups.json", params: { page: -1 }
      expect(response.status).to eq(400)

      get "/groups.json", params: { page: 0 }
      expect(response.status).to eq(200)

      get "/groups.json", params: { page: 1 }
      expect(response.status).to eq(200)
    end

    context "when group directory is disabled" do
      before { SiteSetting.enable_group_directory = false }

      it "should deny access for an anon" do
        get "/groups.json"
        expect(response.status).to eq(403)
      end

      it "should deny access for a normal user" do
        sign_in(user)
        get "/groups.json"

        expect(response.status).to eq(403)
      end

      it "should allow access for an admin" do
        sign_in(admin)
        get "/groups.json"

        expect(response.status).to eq(200)
      end

      it "should allow access for a moderator" do
        sign_in(moderator)
        get "/groups.json"

        expect(response.status).to eq(200)
      end
    end

    context "with searchable" do
      it "should return the searched groups" do
        testing_group = Fabricate(:group, name: "testing")

        get "/groups.json", params: { filter: "test" }

        expect(response.status).to eq(200)

        body = response.parsed_body

        expect(body["groups"].first["id"]).to eq(testing_group.id)
        expect(body["load_more_groups"]).to eq("/groups?filter=test&page=1")
      end
    end

    context "with sortable" do
      before do
        group
        sign_in(user)
      end

      fab!(:group_with_2_users) do
        Fabricate(:group, name: "other_group", users: [user, other_user])
      end

      context "with default (descending) order" do
        it "sorts by name" do
          get "/groups.json", params: { order: "name" }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["groups"].map { |g| g["id"] }).to eq(
            [group_with_2_users.id, group.id, moderator_group_id],
          )

          expect(body["load_more_groups"]).to eq("/groups?order=name&page=1")
        end

        it "sorts by user_count" do
          get "/groups.json", params: { order: "user_count" }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["groups"].map { |g| g["id"] }).to eq(
            [group_with_2_users.id, moderator_group_id, group.id],
          )

          expect(body["load_more_groups"]).to eq("/groups?order=user_count&page=1")
        end
      end

      context "with ascending order" do
        it "sorts by name" do
          get "/groups.json", params: { order: "name", asc: true }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["groups"].map { |g| g["id"] }).to eq(
            [moderator_group_id, group.id, group_with_2_users.id],
          )

          expect(body["load_more_groups"]).to eq("/groups?asc=true&order=name&page=1")
        end

        it "sorts by user_count" do
          get "/groups.json", params: { order: "user_count", asc: "true" }

          expect(response.status).to eq(200)

          body = response.parsed_body

          expect(body["groups"].map { |g| g["id"] }).to eq(
            [moderator_group_id, group.id, group_with_2_users.id],
          )

          expect(body["load_more_groups"]).to eq("/groups?asc=true&order=user_count&page=1")
        end
      end
    end

    it "should return the right response" do
      group
      staff_group

      get "/groups.json"

      expect(response.status).to eq(200)

      body = response.parsed_body

      group_ids = body["groups"].map { |g| g["id"] }

      expect(group_ids).to contain_exactly(group.id)

      expect(body["load_more_groups"]).to eq("/groups?page=1")
      expect(body["total_rows_groups"]).to eq(1)
      expect(body["extras"]["type_filters"].map(&:to_sym)).to eq(
        described_class::TYPE_FILTERS.keys - %i[my owner automatic non_automatic],
      )
    end

    context "when viewing groups of another user" do
      describe "when an invalid username is given" do
        it "should return the right response" do
          group
          get "/groups.json", params: { username: "asdasd" }

          expect(response.status).to eq(404)
        end
      end

      it "should return the right response" do
        u = Fabricate(:user)
        m = Fabricate(:user)
        o = Fabricate(:user)

        levels = Group.visibility_levels.values

        levels
          .product(levels)
          .each do |group_level, members_level|
            g =
              Fabricate(
                :group,
                name: "#{group_level}_#{members_level}",
                visibility_level: group_level,
                members_visibility_level: members_level,
                users: [u],
              )

            if group_level == Group.visibility_levels[:members] ||
                 members_level == Group.visibility_levels[:members]
              g.add(m)
            end
            if group_level == Group.visibility_levels[:owners] ||
                 members_level == Group.visibility_levels[:owners]
              g.add_owner(o)
            end
          end

        # anonymous user
        get "/groups.json", params: { username: u.username }

        expect(response.status).to eq(200)
        group_names = response.parsed_body["groups"].map { |g| g["name"] }
        expect(group_names).to contain_exactly("0_0")

        # logged in user
        sign_in(user)
        get "/groups.json", params: { username: u.username }

        expect(response.status).to eq(200)
        group_names = response.parsed_body["groups"].map { |g| g["name"] }
        expect(group_names).to contain_exactly("0_0", "0_1", "1_0", "1_1")

        # member of the group
        sign_in(m)
        get "/groups.json", params: { username: u.username }

        expect(response.status).to eq(200)
        group_names = response.parsed_body["groups"].map { |g| g["name"] }
        expect(group_names).to contain_exactly(
          "0_0",
          "0_1",
          "0_2",
          "1_0",
          "1_1",
          "1_2",
          "2_0",
          "2_1",
          "2_2",
        )

        # owner
        sign_in(o)
        get "/groups.json", params: { username: u.username }

        expect(response.status).to eq(200)
        group_names = response.parsed_body["groups"].map { |g| g["name"] }
        expect(group_names).to contain_exactly(
          "0_0",
          "0_1",
          "0_4",
          "1_0",
          "1_1",
          "1_4",
          "2_4",
          "3_4",
          "4_0",
          "4_1",
          "4_2",
          "4_3",
          "4_4",
        )

        # moderator
        sign_in(moderator)
        get "/groups.json", params: { username: u.username }

        expect(response.status).to eq(200)
        group_names = response.parsed_body["groups"].map { |g| g["name"] }
        expect(group_names).to contain_exactly(
          "0_0",
          "0_1",
          "0_2",
          "0_3",
          "1_0",
          "1_1",
          "1_2",
          "1_3",
          "2_0",
          "2_1",
          "2_2",
          "2_3",
          "3_0",
          "3_1",
          "3_2",
          "3_3",
        )

        # admin
        sign_in(admin)
        get "/groups.json", params: { username: u.username }

        expect(response.status).to eq(200)
        group_names = response.parsed_body["groups"].map { |g| g["name"] }
        all_group_names = levels.product(levels).map { |a, b| "#{a}_#{b}" }
        expect(group_names).to contain_exactly(*all_group_names)
      end
    end

    context "when viewing as an admin" do
      before do
        sign_in(admin)
        group.add(admin)
        group.add_owner(admin)
      end

      it "should return the right response" do
        staff_group
        get "/groups.json"

        expect(response.status).to eq(200)

        body = response.parsed_body

        group_ids = body["groups"].map { |g| g["id"] }
        group_body = body["groups"].find { |g| g["id"] == group.id }

        expect(group_body["is_group_user"]).to eq(true)
        expect(group_body["is_group_owner"]).to eq(true)
        expect(group_ids).to include(group.id, staff_group.id)
        expect(body["load_more_groups"]).to eq("/groups?page=1")
        expect(body["total_rows_groups"]).to eq(10)

        expect(body["extras"]["type_filters"].map(&:to_sym)).to eq(
          described_class::TYPE_FILTERS.keys - [:non_automatic],
        )
      end

      context "when filterable by type" do
        def expect_type_to_return_right_groups(type, expected_group_ids)
          get "/groups.json", params: { type: type }

          expect(response.status).to eq(200)

          body = response.parsed_body
          group_ids = body["groups"].map { |g| g["id"] }

          expect(body["total_rows_groups"]).to eq(expected_group_ids.count)
          expect(group_ids).to contain_exactly(*expected_group_ids)
        end

        describe "my groups" do
          it "should return the groups admin is a member of" do
            expect_type_to_return_right_groups("my", admin.group_users.map(&:group_id))
          end
        end

        describe "owner groups" do
          it "should return the groups admin is a owner of" do
            group2 = Fabricate(:group)
            _group3 = Fabricate(:group)
            group2.add_owner(admin)

            expect_type_to_return_right_groups(
              "owner",
              admin.group_users.where(owner: true).map(&:group_id),
            )
          end
        end

        describe "automatic groups" do
          it "should return the right response" do
            expect_type_to_return_right_groups("automatic", Group::AUTO_GROUP_IDS.keys - [0])
          end
        end

        describe "non automatic groups" do
          it "should return the right response" do
            group2 = Fabricate(:group)
            expect_type_to_return_right_groups("non_automatic", [group.id, group2.id])
          end
        end

        describe "public groups" do
          it "should return the right response" do
            group2 = Fabricate(:group, public_admission: true)

            expect_type_to_return_right_groups("public", [group2.id])
          end
        end

        describe "close groups" do
          it "should return the right response" do
            group2 = Fabricate(:group, public_admission: false)
            _group3 = Fabricate(:group, public_admission: true)

            expect_type_to_return_right_groups("close", [group.id, group2.id])
          end
        end
      end
    end

    describe "groups_index_query modifier" do
      fab!(:user)
      fab!(:cool_group) { Fabricate(:group, name: "cool-group") }
      fab!(:boring_group) { Fabricate(:group, name: "boring-group") }

      it "allows changing the query" do
        get "/groups.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["groups"].map { |g| g["id"] }).to include(
          cool_group.id,
          boring_group.id,
        )

        get "/groups.json", params: { filter: "cool" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["groups"].map { |g| g["id"] }).to include(cool_group.id)
        expect(response.parsed_body["groups"].map { |g| g["id"] }).not_to include(boring_group.id)

        Plugin::Instance
          .new
          .register_modifier(:groups_index_query) do |query|
            query.where("groups.name LIKE 'cool%'")
          end

        get "/groups.json"
        expect(response.status).to eq(200)
        expect(response.parsed_body["groups"].map { |g| g["id"] }).to include(cool_group.id)
        expect(response.parsed_body["groups"].map { |g| g["id"] }).not_to include(boring_group.id)

        get "/groups.json", params: { filter: "boring" }
        expect(response.status).to eq(200)
        expect(response.parsed_body["groups"].map { |g| g["id"] }).not_to include(
          cool_group.id,
          boring_group.id,
        )
      ensure
        DiscoursePluginRegistry.clear_modifiers!
      end
    end
  end

  describe "#show" do
    it "ensures the group can be seen" do
      sign_in(user)
      group.update!(visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}.json"

      expect(response.status).to eq(404)
    end

    it "returns the right response" do
      sign_in(user)
      mod_group = Group.find(moderator_group_id)
      get "/groups/#{group.name}.json"

      expect(response.status).to eq(200)

      body = response.parsed_body

      expect(body["group"]["id"]).to eq(group.id)
      expect(body["extras"]["visible_group_names"]).to eq([mod_group.name, group.name])
      expect(response.headers["X-Robots-Tag"]).to eq("noindex")
    end

    context "as an admin" do
      it "returns the right response" do
        sign_in(admin)
        get "/groups/#{group.name}.json"

        expect(response.status).to eq(200)

        body = response.parsed_body

        expect(body["group"]["id"]).to eq(group.id)

        groups = Group::AUTO_GROUPS.keys
        groups.delete(:everyone)
        groups.push(group.name)

        expect(body["extras"]["visible_group_names"]).to contain_exactly(*groups.map(&:to_s))
      end
    end

    it "should respond to HTML" do
      group.update!(bio_raw: "testing **group** bio")

      get "/groups/#{group.name}.html"

      expect(response.status).to eq(200)

      expect(response.body).to have_tag "title", text: "#{group.name} - #{SiteSetting.title}"
      expect(response.body).to have_tag(:meta, with: { property: "og:title", content: group.name })

      # note this uses an excerpt so it strips html
      expect(response.body).to have_tag(
        :meta,
        with: {
          property: "og:description",
          content: "testing group bio",
        },
      )
    end

    describe "when viewing activity filters" do
      it "should return the right response" do
        get "/groups/#{group.name}/activity/posts.json"

        expect(response.status).to eq(200)

        body = response.parsed_body["group"]

        expect(body["id"]).to eq(group.id)
      end
    end
  end

  describe "#mentions" do
    it "ensures mentions are enabled" do
      SiteSetting.enable_mentions = false

      sign_in(user)
      get "/groups/#{group.name}/mentions.json"

      expect(response.status).to eq(404)
    end

    it "ensures the group can be seen" do
      sign_in(user)
      group.update!(visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/mentions.json"

      expect(response.status).to eq(404)
    end

    it "ensures the group members can be seen" do
      sign_in(user)
      group.update!(members_visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/mentions.json"

      expect(response.status).to eq(403)
    end

    it "returns the right response" do
      post = Fabricate(:post)
      GroupMention.create!(post: post, group: group)

      sign_in(user)
      get "/groups/#{group.name}/mentions.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)
    end

    it "supports pagination using before (date)" do
      post = Fabricate(:post)
      GroupMention.create!(post: post, group: group)

      sign_in(user)
      get "/groups/#{group.name}/mentions.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)

      get "/groups/#{group.name}/mentions.json", params: { before: post.created_at }

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"]).to be_empty
    end

    it "supports pagination using before_post_id" do
      post = Fabricate(:post)
      GroupMention.create!(post: post, group: group)

      sign_in(user)
      get "/groups/#{group.name}/mentions.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)

      get "/groups/#{group.name}/mentions.json", params: { before_post_id: post.id }

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"]).to be_empty
    end
  end

  describe "#posts" do
    it "ensures the group can be seen" do
      sign_in(user)
      group.update!(visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(404)
    end

    it "ensures the group members can be seen" do
      sign_in(user)
      group.update!(members_visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(403)
    end

    it "calls `posts_for` and responds with JSON" do
      sign_in(user)
      post = Fabricate(:post, user: user)
      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)
    end

    it "returns moderator actions" do
      sign_in(user)
      post = Fabricate(:post, user: user, post_type: Post.types[:moderator_action])
      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)
    end

    it "supports pagination using before (date)" do
      post = Fabricate(:post, user: user)

      sign_in(user)
      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)

      get "/groups/#{group.name}/posts.json", params: { before: post.created_at }

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"]).to be_empty
    end

    it "supports pagination using before_post_id" do
      post = Fabricate(:post, user: user)

      sign_in(user)
      get "/groups/#{group.name}/posts.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"].first["id"]).to eq(post.id)

      get "/groups/#{group.name}/posts.json", params: { before_post_id: post.id }

      expect(response.status).to eq(200)
      expect(response.parsed_body["posts"]).to be_empty
    end
  end

  describe "#members" do
    it "returns correct error code with invalid params" do
      sign_in(user)

      get "/groups/#{group.name}/members.json?limit=-1"
      expect(response.status).to eq(400)

      get "/groups/#{group.name}/members.json?offset=-1"
      expect(response.status).to eq(400)

      get "/groups/trust_level_0/members.json?limit=2000"
      expect(response.status).to eq(400)
    end

    it "ensures the group can be seen" do
      sign_in(user)
      group.update!(visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/members.json"

      expect(response.status).to eq(404)
    end

    it "ensures the group members can be seen" do
      group.update!(members_visibility_level: Group.visibility_levels[:logged_on_users])

      get "/groups/#{group.name}/members.json", params: { limit: 1 }

      expect(response.status).to eq(403)
    end

    it "ensures that membership can be paginated" do
      freeze_time

      first_user = Fabricate(:user)
      group.add(first_user)

      freeze_time 1.day.from_now

      4.times { group.add(Fabricate(:user)) }
      usernames = group.users.map { |m| m.username }.sort

      get "/groups/#{group.name}/members.json", params: { limit: 3, asc: true }

      expect(response.status).to eq(200)

      members = response.parsed_body["members"]

      expect(members.map { |m| m["username"] }).to eq(usernames[0..2])

      get "/groups/#{group.name}/members.json", params: { limit: 3, offset: 3, asc: true }

      expect(response.status).to eq(200)

      members = response.parsed_body["members"]

      expect(members.map { |m| m["username"] }).to eq(usernames[3..5])

      get "/groups/#{group.name}/members.json", params: { order: "added_at" }
      members = response.parsed_body["members"]

      expect(members.last["added_at"]).to eq(first_user.created_at.as_json)
    end

    it "can sort items" do
      sign_in(user)
      group.update!(visibility_level: Group.visibility_levels[:logged_on_users])
      other_user = Fabricate(:user)
      group.add_owner(other_user)

      get "/groups/#{group.name}/members.json"

      expect(response.parsed_body["members"].map { |u| u["id"] }).to eq([other_user.id, user.id])
      expect(response.parsed_body["owners"].map { |u| u["id"] }).to eq([other_user.id])

      get "/groups/#{group.name}/members.json?order=added_at&asc=1"

      expect(response.parsed_body["members"].map { |u| u["id"] }).to eq([user.id, other_user.id])
      expect(response.parsed_body["owners"].map { |u| u["id"] }).to eq([other_user.id])
    end

    context "when include_custom_fields is true" do
      fab!(:user_field)
      let(:user_field_name) { "user_field_#{user_field.id}" }
      let!(:custom_user_field) do
        UserCustomField.create!(user_id: user.id, name: user_field_name, value: "A custom field")
      end

      before do
        sign_in(user)
        SiteSetting.public_user_custom_fields = user_field_name
      end

      it "shows the custom fields" do
        get "/groups/#{group.name}/members.json", params: { include_custom_fields: true }

        expect(response.status).to eq(200)
        response_custom_fields = response.parsed_body["members"].first["custom_fields"]
        expect(response_custom_fields[user_field_name]).to eq("A custom field")
      end

      it "allows sorting by custom fields" do
        group.add(user2)
        UserCustomField.create!(user_id: user2.id, name: user_field_name, value: "C custom field")
        group.add(other_user)
        UserCustomField.create!(
          user_id: other_user.id,
          name: user_field_name,
          value: "B custom field",
        )

        get "/groups/#{group.name}/members.json",
            params: {
              include_custom_fields: true,
              order: "custom_field",
              order_field: user_field_name,
              asc: true,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["members"].pluck("id")).to eq(
          [user.id, other_user.id, user2.id],
        )

        get "/groups/#{group.name}/members.json",
            params: {
              include_custom_fields: true,
              order: "custom_field",
              order_field: user_field_name,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["members"].pluck("id")).to eq(
          [user2.id, other_user.id, user.id],
        )
      end
    end
  end

  describe "#posts_feed" do
    it "renders RSS" do
      get "/groups/#{group.name}/posts.rss"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/rss+xml")
    end
  end

  describe "#mentions_feed" do
    it "renders RSS" do
      get "/groups/#{group.name}/mentions.rss"

      expect(response.status).to eq(200)
      expect(response.media_type).to eq("application/rss+xml")
    end

    it "fails when disabled" do
      SiteSetting.enable_mentions = false

      get "/groups/#{group.name}/mentions.rss"

      expect(response.status).to eq(404)
    end
  end

  describe "#mentionable" do
    it "should return the right response" do
      sign_in(user)

      group.update!(
        mentionable_level: Group::ALIAS_LEVELS[:owners_mods_and_admins],
        visibility_level: Group.visibility_levels[:logged_on_users],
      )

      get "/groups/#{group.name}/mentionable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["mentionable"]).to eq(false)

      group.update!(
        mentionable_level: Group::ALIAS_LEVELS[:everyone],
        visibility_level: Group.visibility_levels[:staff],
      )

      get "/groups/#{group.name}/mentionable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["mentionable"]).to eq(true)

      group.update!(
        mentionable_level: Group::ALIAS_LEVELS[:nobody],
        visibility_level: Group.visibility_levels[:public],
      )

      get "/groups/#{group.name}/mentionable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["mentionable"]).to eq(true)
    end
  end

  describe "#messageable" do
    it "should return the right response" do
      user.change_trust_level!(1)
      sign_in(user)

      get "/groups/#{group.name}/messageable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["messageable"]).to eq(false)

      group.update!(
        messageable_level: Group::ALIAS_LEVELS[:everyone],
        visibility_level: Group.visibility_levels[:staff],
      )

      get "/groups/#{group.name}/messageable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["messageable"]).to eq(true)

      SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff]

      get "/groups/#{group.name}/messageable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["messageable"]).to eq(true)

      group.update!(messageable_level: Group::ALIAS_LEVELS[:only_admins])

      get "/groups/#{group.name}/messageable.json"
      expect(response.status).to eq(200)

      body = response.parsed_body
      expect(body["messageable"]).to eq(false)
    end
  end

  describe "#update" do
    let!(:group) do
      Fabricate(:group, name: "test", users: [user], public_admission: false, public_exit: false)
    end
    let(:category) { Fabricate(:category) }
    let(:tag) { Fabricate(:tag) }

    context "with custom_fields" do
      before do
        user.update!(admin: true)
        sign_in(user)
        plugin = Plugin::Instance.new
        plugin.register_editable_group_custom_field :test
        @group = Fabricate(:group)
      end

      after { DiscoursePluginRegistry.reset! }

      it "only updates allowed user fields" do
        put "/groups/#{@group.id}.json",
            params: {
              group: {
                custom_fields: {
                  test: :hello1,
                  test2: :hello2,
                },
              },
            }

        @group.reload

        expect(response.status).to eq(200)
        expect(@group.custom_fields["test"]).to eq("hello1")
        expect(@group.custom_fields["test2"]).to be_blank
      end

      it "is secure when there are no registered editable fields" do
        DiscoursePluginRegistry.reset!
        put "/groups/#{@group.id}.json",
            params: {
              group: {
                custom_fields: {
                  test: :hello1,
                  test2: :hello2,
                },
              },
            }

        @group.reload

        expect(response.status).to eq(200)
        expect(@group.custom_fields["test"]).to be_blank
        expect(@group.custom_fields["test2"]).to be_blank
      end
    end

    context "when user is group owner" do
      before do
        group.add_owner(user)
        sign_in(user)
      end

      it "should be able update the group" do
        group.update!(
          allow_membership_requests: false,
          visibility_level: 2,
          mentionable_level: 2,
          messageable_level: 2,
          default_notification_level: 0,
          grant_trust_level: 0,
        )

        expect do
          put "/groups/#{group.id}.json",
              params: {
                group: {
                  mentionable_level: 1,
                  messageable_level: 1,
                  visibility_level: 1,
                  automatic_membership_email_domains: "test.org",
                  title: "haha",
                  primary_group: true,
                  grant_trust_level: 1,
                  incoming_email: "test@mail.org",
                  flair_bg_color: "FFF",
                  flair_color: "BBB",
                  flair_icon: "fa-circle-half-stroke",
                  bio_raw: "testing",
                  full_name: "awesome team",
                  public_admission: true,
                  public_exit: true,
                  allow_membership_requests: true,
                  membership_request_template: "testing",
                  default_notification_level: 1,
                  name: "testing",
                  tracking_category_ids: [category.id],
                  tracking_tags: [tag.name],
                },
                update_existing_users: false,
              }
        end.to change { GroupHistory.count }.by(13)

        expect(response.status).to eq(200)

        group.reload

        expect(group.flair_bg_color).to eq("FFF")
        expect(group.flair_color).to eq("BBB")
        expect(group.flair_url).to eq("fa-circle-half-stroke")
        expect(group.bio_raw).to eq("testing")
        expect(group.full_name).to eq("awesome team")
        expect(group.public_admission).to eq(true)
        expect(group.public_exit).to eq(true)
        expect(group.allow_membership_requests).to eq(true)
        expect(group.membership_request_template).to eq("testing")
        expect(group.name).to eq("test")
        expect(group.visibility_level).to eq(2)
        expect(group.mentionable_level).to eq(1)
        expect(group.messageable_level).to eq(1)
        expect(group.default_notification_level).to eq(1)
        expect(group.automatic_membership_email_domains).to eq(nil)
        expect(group.title).to eq("haha")
        expect(group.primary_group).to eq(false)
        expect(group.incoming_email).to eq(nil)
        expect(group.grant_trust_level).to eq(0)
        expect(group.group_category_notification_defaults.first&.category).to eq(category)
        expect(group.group_tag_notification_defaults.first&.tag).to eq(tag)
      end

      it "should not be allowed to update automatic groups" do
        group = Group.find(Group::AUTO_GROUPS[:admins])

        put "/groups/#{group.id}.json", params: { group: { messageable_level: 1 } }

        expect(response.status).to eq(403)
      end
    end

    context "when user is group admin" do
      before { sign_in(admin) }

      it "should be able to update the group" do
        group.update!(visibility_level: 2, members_visibility_level: 2, grant_trust_level: 0)

        put "/groups/#{group.id}.json",
            params: {
              group: {
                flair_color: "BBB",
                name: "testing",
                incoming_email: "test@mail.org",
                primary_group: true,
                automatic_membership_email_domains: "test.org",
                grant_trust_level: 2,
                visibility_level: 1,
                members_visibility_level: 3,
                tracking_category_ids: [category.id],
                tracking_tags: [tag.name],
              },
              update_existing_users: false,
            }

        expect(response.status).to eq(200)

        group.reload
        expect(group.flair_color).to eq("BBB")
        expect(group.name).to eq("testing")
        expect(group.incoming_email).to eq("test@mail.org")
        expect(group.primary_group).to eq(true)
        expect(group.visibility_level).to eq(1)
        expect(group.members_visibility_level).to eq(3)
        expect(group.automatic_membership_email_domains).to eq("test.org")
        expect(group.grant_trust_level).to eq(2)
        expect(group.group_category_notification_defaults.first&.category).to eq(category)
        expect(group.group_tag_notification_defaults.first&.tag).to eq(tag)

        expect(Jobs::AutomaticGroupMembership.jobs.first["args"].first["group_id"]).to eq(group.id)
      end

      it "they should be able to update an automatic group" do
        group = Group.find(Group::AUTO_GROUPS[:admins])

        group.update!(
          visibility_level: 2,
          mentionable_level: 2,
          messageable_level: 2,
          default_notification_level: 2,
          members_visibility_level: 2,
        )

        put "/groups/#{group.id}.json",
            params: {
              group: {
                flair_bg_color: "FFF",
                flair_color: "BBB",
                flair_icon: "fa-circle-half-stroke",
                name: "testing",
                visibility_level: 1,
                mentionable_level: 1,
                messageable_level: 1,
                default_notification_level: 1,
                members_visibility_level: 1,
                tracking_category_ids: [category.id],
                tracking_tags: [tag.name],
              },
              update_existing_users: false,
            }

        expect(response.status).to eq(200)

        group.reload
        expect(group.flair_bg_color).to eq("FFF")
        expect(group.flair_color).to eq("BBB")
        expect(group.flair_icon).to eq("fa-circle-half-stroke")
        expect(group.flair_url).to eq("fa-circle-half-stroke")
        expect(group.name).to eq("admins")
        expect(group.visibility_level).to eq(1)
        expect(group.mentionable_level).to eq(1)
        expect(group.messageable_level).to eq(1)
        expect(group.default_notification_level).to eq(1)
        expect(group.members_visibility_level).to eq(1)
        expect(group.group_category_notification_defaults.first&.category).to eq(category)
        expect(group.group_tag_notification_defaults.first&.tag).to eq(tag)
      end

      it "triggers a extensibility event" do
        event =
          DiscourseEvent
            .track_events do
              put "/groups/#{group.id}.json", params: { group: { flair_color: "BBB" } }
            end
            .last

        expect(event[:event_name]).to eq(:group_updated)
        expect(event[:params].first).to eq(group)
      end

      context "with user default notifications" do
        it "should update default notification preference for existing users" do
          group.update!(default_notification_level: NotificationLevels.all[:watching])
          user1 = Fabricate(:user)
          group.add(user1)
          group.add(user2)
          group_user1 = user1.group_users.first
          group_user2 = user2.group_users.first

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  default_notification_level: NotificationLevels.all[:tracking],
                },
              }

          expect(response.status).to eq(422)
          expect(response.parsed_body["user_count"]).to eq(group.group_users.count)
          expect(response.parsed_body["errors"].first).to include("update_existing_users")
          expect(group_user1.reload.notification_level).to eq(NotificationLevels.all[:watching])
          expect(group_user2.reload.notification_level).to eq(NotificationLevels.all[:watching])

          group_user1.update!(notification_level: NotificationLevels.all[:regular])

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  default_notification_level: NotificationLevels.all[:tracking],
                },
              }

          expect(response.status).to eq(422)
          expect(response.parsed_body["user_count"]).to eq(group.group_users.count - 1)
          expect(group_user1.reload.notification_level).to eq(NotificationLevels.all[:regular])
          expect(group_user2.reload.notification_level).to eq(NotificationLevels.all[:watching])

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  default_notification_level: NotificationLevels.all[:tracking],
                },
                update_existing_users: true,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["success"]).to eq("OK")
          expect(group_user1.reload.notification_level).to eq(NotificationLevels.all[:regular])
          expect(group_user2.reload.notification_level).to eq(NotificationLevels.all[:tracking])

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  default_notification_level: NotificationLevels.all[:regular],
                },
                update_existing_users: false,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["success"]).to eq("OK")
          expect(group_user1.reload.notification_level).to eq(NotificationLevels.all[:regular])
          expect(group_user2.reload.notification_level).to eq(NotificationLevels.all[:tracking])
        end

        it "should update category & tag notification preferences for existing users" do
          user1 = Fabricate(:user)
          CategoryUser.create!(user: user1, category: category, notification_level: 4)
          TagUser.create!(user: user1, tag: tag, notification_level: 4)
          TagUser.create!(user: user2, tag: tag, notification_level: 4)
          group.add(user1)
          group.add(user2)

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  flair_color: "BBB",
                  name: "testing",
                  incoming_email: "test@mail.org",
                  primary_group: true,
                  automatic_membership_email_domains: "test.org",
                  grant_trust_level: 2,
                  visibility_level: 1,
                  members_visibility_level: 3,
                  tracking_category_ids: [category.id],
                  tracking_tags: [tag.name],
                },
              }

          expect(response.status).to eq(422)
          expect(response.parsed_body["user_count"]).to eq(group.group_users.count - 1)

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  flair_color: "BBB",
                  name: "testing",
                  incoming_email: "test@mail.org",
                  primary_group: true,
                  automatic_membership_email_domains: "test.org",
                  grant_trust_level: 2,
                  visibility_level: 1,
                  members_visibility_level: 3,
                  tracking_category_ids: [category.id],
                  tracking_tags: [tag.name],
                },
                update_existing_users: true,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["success"]).to eq("OK")

          put "/groups/#{group.id}.json",
              params: {
                group: {
                  flair_color: "BBB",
                  name: "testing",
                  incoming_email: "test@mail.org",
                  primary_group: true,
                  automatic_membership_email_domains: "test.org",
                  grant_trust_level: 2,
                  visibility_level: 1,
                  members_visibility_level: 3,
                  watching_category_ids: [category.id],
                  tracking_tags: [tag.name],
                },
                update_existing_users: true,
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["success"]).to eq("OK")
          expect(
            CategoryUser.exists?(user: user2, category: category, notification_level: 3),
          ).to be_truthy
        end
      end
    end

    context "when user is a site moderator" do
      before do
        SiteSetting.moderators_manage_categories_and_groups = true
        sign_in(moderator)
      end

      it "should not be able to update the group if the SiteSetting is false" do
        SiteSetting.moderators_manage_categories_and_groups = false

        put "/groups/#{group.id}.json", params: { group: { name: "testing" } }

        expect(response.status).to eq(403)
      end

      it "should not be able to update a group it cannot see" do
        group.update!(visibility_level: Group.visibility_levels[:owners])

        put "/groups/#{group.id}.json", params: { group: { name: "testing" } }

        expect(response.status).to eq(403)
      end

      it "should be able to update the group" do
        put "/groups/#{group.id}.json",
            params: {
              group: {
                flair_color: "BBB",
                name: "testing",
                incoming_email: "test@mail.org",
                primary_group: true,
                automatic_membership_email_domains: "test.org",
                grant_trust_level: 2,
                visibility_level: 1,
                members_visibility_level: 3,
                tracking_category_ids: [category.id],
                tracking_tags: [tag.name],
              },
              update_existing_users: false,
            }

        expect(response.status).to eq(200)

        group.reload
        expect(group.flair_color).to eq("BBB")
        expect(group.name).to eq("testing")
        expect(group.incoming_email).to eq("test@mail.org")
        expect(group.primary_group).to eq(true)
        expect(group.visibility_level).to eq(1)
        expect(group.members_visibility_level).to eq(3)
        expect(group.automatic_membership_email_domains).to eq("test.org")
        expect(group.grant_trust_level).to eq(2)
        expect(group.group_category_notification_defaults.first&.category).to eq(category)
        expect(group.group_tag_notification_defaults.first&.tag).to eq(tag)

        expect(Jobs::AutomaticGroupMembership.jobs.first["args"].first["group_id"]).to eq(group.id)
      end

      it "should be able to update an automatic group" do
        group = Group.find(Group::AUTO_GROUPS[:trust_level_4])

        group.update!(mentionable_level: 2, messageable_level: 2, default_notification_level: 2)

        put "/groups/#{group.id}.json",
            params: {
              group: {
                flair_bg_color: "FFF",
                flair_color: "BBB",
                flair_icon: "fa-circle-half-stroke",
                mentionable_level: 1,
                messageable_level: 1,
                default_notification_level: 1,
              },
            }

        expect(response.status).to eq(200)

        group.reload
        expect(group.flair_bg_color).to eq("FFF")
        expect(group.flair_color).to eq("BBB")
        expect(group.flair_icon).to eq("fa-circle-half-stroke")
        expect(group.flair_url).to eq("fa-circle-half-stroke")
        expect(group.name).to eq("trust_level_4")
        expect(group.mentionable_level).to eq(1)
        expect(group.messageable_level).to eq(1)
        expect(group.default_notification_level).to eq(1)
      end

      it "triggers a extensibility event" do
        event =
          DiscourseEvent
            .track_events do
              put "/groups/#{group.id}.json", params: { group: { flair_color: "BBB" } }
            end
            .last

        expect(event[:event_name]).to eq(:group_updated)
        expect(event[:params].first).to eq(group)
      end
    end

    context "when user is not a group owner or admin" do
      it "should not be able to update the group" do
        sign_in(user)

        put "/groups/#{group.id}.json", params: { group: { name: "testing" } }

        expect(response.status).to eq(403)
      end
    end
  end

  describe "#members" do
    let(:user1) do
      Fabricate(
        :user,
        last_seen_at: Time.zone.now,
        last_posted_at: Time.zone.now - 1.day,
        email: "b@test.org",
      )
    end

    let(:user2) do
      Fabricate(
        :user,
        last_seen_at: Time.zone.now - 1.day,
        last_posted_at: Time.zone.now,
        email: "a@test.org",
      )
    end

    fab!(:user3) { Fabricate(:user, last_seen_at: nil, last_posted_at: nil, email: "c@test.org") }

    fab!(:bot)
    let(:group) { Fabricate(:group, users: [user1, user2, user3, bot]) }

    it "should allow members to be sorted by" do
      get "/groups/#{group.name}/members.json", params: { order: "last_seen_at" }

      expect(response.status).to eq(200)

      members = response.parsed_body["members"]

      expect(members.map { |m| m["id"] }).to eq([user1.id, user2.id, user3.id])

      get "/groups/#{group.name}/members.json", params: { order: "last_seen_at", asc: true }

      expect(response.status).to eq(200)

      members = response.parsed_body["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id, user3.id])

      get "/groups/#{group.name}/members.json", params: { order: "last_posted_at" }

      expect(response.status).to eq(200)

      members = response.parsed_body["members"]

      expect(members.map { |m| m["id"] }).to eq([user2.id, user1.id, user3.id])
    end

    it "should not allow members to be sorted by columns that are not allowed" do
      get "/groups/#{group.name}/members.json", params: { order: "email" }

      expect(response.status).to eq(200)

      members = response.parsed_body["members"]

      expect(members.map { |m| m["id"] }).to contain_exactly(user1.id, user2.id, user3.id)
    end

    it "can show group requests" do
      sign_in(admin)

      user4 = Fabricate(:user)
      request4 = Fabricate(:group_request, user: user4, group: group)

      get "/groups/#{group.name}/members.json", params: { requesters: true }

      members = response.parsed_body["members"]
      expect(members.length).to eq(1)
      expect(members.first["username"]).to eq(user4.username)
      expect(members.first["reason"]).to eq(request4.reason)
    end

    describe "filterable" do
      describe "as a normal user" do
        it "should not allow members to be filterable by email" do
          email = "uniquetest@discourse.org"
          user1.update!(email: email)

          get "/groups/#{group.name}/members.json", params: { filter: email }

          expect(response.status).to eq(200)
          members = response.parsed_body["members"]
          expect(members).to eq([])
        end
      end

      describe "as an admin" do
        before { sign_in(admin) }

        it "should allow members to be filterable by username" do
          email = "uniquetest@discourse.org"
          user1.update!(email: email)

          {
            email.upcase => [user1.id],
            "QUEtes" => [user1.id],
            "#{user1.email},#{user2.email}" => [user1.id, user2.id],
          }.each do |filter, ids|
            get "/groups/#{group.name}/members.json", params: { filter: filter }

            expect(response.status).to eq(200)
            members = response.parsed_body["members"]
            expect(members.map { |m| m["id"] }).to contain_exactly(*ids)
          end
        end

        it "should allow members to be filterable by email" do
          username = "uniquetest"
          user1.update!(username: username)

          [username.upcase, "QUEtes"].each do |filter|
            get "/groups/#{group.name}/members.json", params: { filter: filter }

            expect(response.status).to eq(200)
            members = response.parsed_body["members"]
            expect(members.map { |m| m["id"] }).to contain_exactly(user1.id)
          end
        end
      end
    end
  end

  describe "#edit" do
    fab!(:group)

    context "when user is not signed in" do
      it "should be forbidden" do
        put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
        expect(response).to be_forbidden

        delete "/groups/#{group.id}/members.json", params: { username: "bob" }
        expect(response).to be_forbidden
      end

      context "with public group" do
        it "should be forbidden" do
          group.update!(public_admission: true, public_exit: true)

          put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
          expect(response.status).to eq(403)

          delete "/groups/#{group.id}/members.json", params: { username: "bob" }
          expect(response.status).to eq(403)
        end
      end
    end

    context "when user is not an owner of the group" do
      before { sign_in(user) }

      it "refuses membership changes to unauthorized users" do
        put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
        expect(response).to be_forbidden

        delete "/groups/#{group.id}/members.json", params: { username: "bob" }
        expect(response).to be_forbidden
      end
    end

    context "when user is an admin" do
      fab!(:group) { Fabricate(:group, users: [admin], automatic: true) }

      before { sign_in(admin) }

      it "cannot add members to automatic groups" do
        put "/groups/#{group.id}/members.json", params: { usernames: "bob" }
        expect(response).to be_forbidden

        delete "/groups/#{group.id}/members.json", params: { username: "bob" }
        expect(response).to be_forbidden
      end
    end
  end

  describe "membership edits" do
    describe "#add_members" do
      before { sign_in(admin) }

      it "can make incremental adds" do
        expect do
          put "/groups/#{group.id}/members.json", params: { usernames: user2.username }
        end.to change { group.users.count }.by(1)

        expect(response.status).to eq(200)

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
        expect(group_history.acting_user).to eq(admin)
        expect(group_history.target_user).to eq(user2)
      end

      it "cannot add members to automatic groups" do
        group.update!(automatic: true)

        put "/groups/#{group.id}/members.json", params: { usernames: "l77t" }
        expect(response.status).to eq(403)
      end

      it "does not notify users when the param is not present" do
        expect {
          put "/groups/#{group.id}/members.json", params: { usernames: user2.username }
        }.not_to change { Topic.where(archetype: "private_message").count }

        expect(response.status).to eq(200)
      end

      it "notifies users when the param is present" do
        expect {
          put "/groups/#{group.id}/members.json",
              params: {
                usernames: user2.username,
                notify_users: true,
              }
        }.to change { Topic.where(archetype: "private_message").count }.by(1)

        expect(response.status).to eq(200)

        expect(Topic.last.topic_users.map(&:user_id)).to include(
          Discourse::SYSTEM_USER_ID,
          user2.id,
        )
      end

      it "does not add users without sufficient permission" do
        group.add_owner(user)
        sign_in(user)

        put "/groups/#{group.id}/members.json", params: { usernames: other_user.username }
        expect(response.status).to eq(200)
      end

      it "does not send invites if user cannot invite" do
        group.add_owner(user)
        sign_in(user)

        put "/groups/#{group.id}/members.json", params: { emails: "test@example.com" }
        expect(response.status).to eq(403)
      end

      context "when is able to add several members to a group" do
        fab!(:user1) { Fabricate(:user) }
        fab!(:user2) { Fabricate(:user, username: "UsEr2") }

        it "adds by username" do
          expect do
            put "/groups/#{group.id}/members.json",
                params: {
                  usernames: [user1.username, user2.username.upcase].join(","),
                }
          end.to change { group.users.count }.by(2)

          expect(response.status).to eq(200)
        end

        it "adds by id" do
          expect do
            put "/groups/#{group.id}/members.json",
                params: {
                  user_ids: [user1.id, user2.id].join(","),
                }
          end.to change { group.users.count }.by(2)

          expect(response.status).to eq(200)
        end

        it "adds by email" do
          expect do
            put "/groups/#{group.id}/members.json",
                params: {
                  user_emails: [user1.email, user2.email].join(","),
                }
          end.to change { group.users.count }.by(2)

          expect(response.status).to eq(200)
        end

        it "adds missing users even if some exists" do
          user2.update!(username: "alice")
          user3 = Fabricate(:user, username: "bob")
          [user2, user3].each { |user| group.add(user) }

          expect do
            put "/groups/#{group.id}/members.json",
                params: {
                  user_emails: [user1.email, user2.email, user3.email].join(","),
                }
          end.to change { group.users.count }.by(1)

          expect(response.status).to eq(200)
        end

        it "sends invites to new users and ignores existing users" do
          user1.update!(username: "john")
          user2.update!(username: "alice")
          [user1, user2].each { |user| group.add(user) }
          emails = %w[something@gmail.com anotherone@yahoo.com]
          put "/groups/#{group.id}/members.json",
              params: {
                user_emails: [user1.email, user2.email].join(","),
                emails: emails.join(","),
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["emails"]).to eq(emails)

          emails.each do |email|
            invite = Invite.find_by(email: email)
            expect(invite.groups).to eq([group])
          end
        end

        it "displays warning when all members already exists" do
          user1.update!(username: "john")
          user2.update!(username: "alice")
          user3 = Fabricate(:user, username: "bob")
          [user1, user2, user3].each { |user| group.add(user) }

          expect do
            put "/groups/#{group.id}/members.json",
                params: {
                  user_emails: [user1.email, user2.email, user3.email].join(","),
                }
          end.not_to change { group.users.count }

          expect(response.status).to eq(422)

          expect(response.parsed_body["errors"]).to include(
            I18n.t("groups.errors.member_already_exist", username: "alice, bob, john", count: 3),
          )
        end

        it "display error when try to add to many users at once" do
          stub_const(GroupsController, "ADD_MEMBERS_LIMIT", 1) do
            expect do
              put "/groups/#{group.id}/members.json",
                  params: {
                    user_emails: [user1.email, user2.email].join(","),
                  }
            end.not_to change { group.reload.users.count }

            expect(response.status).to eq(422)

            expect(response.parsed_body["errors"]).to include(
              I18n.t("groups.errors.adding_too_many_users", count: 1),
            )
          end
        end
      end

      it "returns 422 if member already exists" do
        put "/groups/#{group.id}/members.json", params: { usernames: user.username }

        expect(response.status).to eq(422)

        expect(response.parsed_body["errors"]).to include(
          I18n.t("groups.errors.member_already_exist", username: user.username, count: 1),
        )
      end

      it "returns 400 if member is not found" do
        [
          { usernames: "some thing" },
          { user_ids: "-5,-6" },
          { user_emails: "some@test.org" },
        ].each do |params|
          put "/groups/#{group.id}/members.json", params: params

          expect(response.status).to eq(400)

          body = response.parsed_body

          expect(body["error_type"]).to eq("invalid_parameters")
        end
      end

      it "return a 400 if no user or emails are present" do
        [
          { usernames: "nouserwiththisusername", emails: "" },
          { usernames: "", emails: "" },
        ].each do |params|
          put "/groups/#{group.id}/members.json", params: params
          expect(response.status).to eq(400)
          body = response.parsed_body

          expect(body["error_type"]).to eq("invalid_parameters")
        end
      end

      it "will send invites to each email with group_id set" do
        emails = %w[something@gmail.com anotherone@yahoo.com]
        put "/groups/#{group.id}/members.json", params: { emails: emails.join(",") }

        expect(response.status).to eq(200)
        body = response.parsed_body

        expect(body["emails"]).to eq(emails)

        emails.each do |email|
          invite = Invite.find_by(email: email)
          expect(invite.groups).to eq([group])
        end
      end

      it "adds known users by email when DiscourseConnect is enabled" do
        SiteSetting.discourse_connect_url = "https://www.example.com/sso"
        SiteSetting.enable_discourse_connect = true

        expect do
          put "/groups/#{group.id}/members.json", params: { emails: other_user.email }
        end.to change { group.users.count }.by(1)

        expect(response.status).to eq(200)
      end

      it "will find users by email, and invite the correct user" do
        new_user = Fabricate(:user)
        expect(new_user.group_ids.include?(group.id)).to eq(false)

        put "/groups/#{group.id}/members.json", params: { emails: new_user.email }

        expect(new_user.reload.group_ids.include?(group.id)).to eq(true)
      end

      it "will invite the user if their username and email are both invited" do
        new_user = Fabricate(:user)
        put "/groups/#{group.id}/members.json",
            params: {
              usernames: new_user.username,
              emails: new_user.email,
            }
        expect(response.status).to eq(200)
        expect(new_user.reload.group_ids.include?(group.id)).to eq(true)
      end

      context "with public group" do
        before { group.update!(public_admission: true, public_exit: true) }

        context "when admin" do
          it "can make incremental adds" do
            expect do
              put "/groups/#{group.id}/members.json", params: { usernames: other_user.username }
            end.to change { group.users.count }.by(1)

            expect(response.status).to eq(200)

            group_history = GroupHistory.last

            expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
            expect(group_history.acting_user).to eq(admin)
            expect(group_history.target_user).to eq(other_user)
          end
        end
      end
    end

    describe "#add_owners" do
      context "when logged in as an admin" do
        before { sign_in(admin) }

        it "should work" do
          put "/groups/#{group.id}/owners.json",
              params: {
                usernames: [user.username, admin.username].join(","),
              }

          expect(response.status).to eq(200)

          response_body = response.parsed_body

          expect(response_body["usernames"]).to contain_exactly(user.username, admin.username)

          expect(group.group_users.where(owner: true).map(&:user)).to contain_exactly(user, admin)
        end

        it "returns not-found error when there is no group" do
          group.destroy!

          put "/groups/#{group.id}/owners.json", params: { usernames: user.username }

          expect(response.status).to eq(404)
        end

        it "does not allow adding owners to an automatic group" do
          group.update!(automatic: true)

          expect do
            put "/groups/#{group.id}/owners.json", params: { usernames: user.username }
          end.to_not change { group.group_users.count }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to eq(
            [I18n.t("groups.errors.can_not_modify_automatic")],
          )
        end

        it "does not notify users when the param is not present" do
          put "/groups/#{group.id}/owners.json", params: { usernames: user.username }
          expect(response.status).to eq(200)

          topic =
            Topic.find_by(
              title:
                I18n.t(
                  "system_messages.user_added_to_group_as_owner.subject_template",
                  group_name: group.name,
                ),
              archetype: "private_message",
            )
          expect(topic.nil?).to eq(true)
        end

        it "notifies users when the param is present" do
          put "/groups/#{group.id}/owners.json",
              params: {
                usernames: user.username,
                notify_users: true,
              }
          expect(response.status).to eq(200)

          topic =
            Topic.find_by(
              title:
                I18n.t(
                  "system_messages.user_added_to_group_as_owner.subject_template",
                  group_name: group.name,
                ),
              archetype: "private_message",
            )
          expect(topic.nil?).to eq(false)
          expect(topic.topic_users.map(&:user_id)).to include(-1, user.id)
        end
      end

      context "when logged in as a moderator" do
        before { sign_in(moderator) }

        context "with moderators_manage_categories_and_groups enabled" do
          before { SiteSetting.moderators_manage_categories_and_groups = true }

          it "adds owners" do
            put "/groups/#{group.id}/owners.json",
                params: {
                  usernames: [user.username, admin.username, moderator.username].join(","),
                }

            response_body = response.parsed_body

            expect(response.status).to eq(200)
            expect(response_body["usernames"]).to contain_exactly(
              user.username,
              admin.username,
              moderator.username,
            )
            expect(group.group_users.where(owner: true).map(&:user)).to contain_exactly(
              user,
              admin,
              moderator,
            )
          end
        end

        context "with moderators_manage_categories_and_groups disabled" do
          before { SiteSetting.moderators_manage_categories_and_groups = false }

          it "prevents adding of owners with a 403 response" do
            put "/groups/#{group.id}/owners.json",
                params: {
                  usernames: [user.username, admin.username, moderator.username].join(","),
                }

            expect(response.status).to eq(403)
            expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
            expect(group.group_users.where(owner: true).map(&:user)).to be_empty
          end
        end
      end

      context "when logged in as a non-owner" do
        before { sign_in(user) }

        it "prevents adding of owners with a 403 response" do
          put "/groups/#{group.id}/owners.json",
              params: {
                usernames: [user.username, admin.username].join(","),
              }

          expect(response.status).to eq(403)
          expect(response.parsed_body["errors"]).to include(I18n.t("invalid_access"))
          expect(group.group_users.where(owner: true).map(&:user)).to be_empty
        end
      end

      context "when logged in as an owner" do
        before { sign_in(user) }

        it "allows adding new owners" do
          group.add_owner(user)

          put "/groups/#{group.id}/owners.json",
              params: {
                usernames: [user.username, admin.username].join(","),
              }

          expect(response.status).to eq(200)
          expect(response.parsed_body["usernames"]).to contain_exactly(
            user.username,
            admin.username,
          )
          expect(group.group_users.where(owner: true).map(&:user)).to contain_exactly(user, admin)
        end
      end
    end

    describe "#join" do
      let(:public_group) { Fabricate(:public_group) }

      it "should allow a user to join a public group" do
        sign_in(user)

        expect do put "/groups/#{public_group.id}/join.json" end.to change {
          public_group.users.count
        }.by(1)

        expect(response.status).to eq(204)
      end

      it "should not allow a user to join a nonpublic group" do
        sign_in(user)

        expect do put "/groups/#{group.id}/join.json" end.not_to change { group.users.count }

        expect(response).to be_forbidden
      end

      it "should not allow an anonymous user to call the join method" do
        expect do put "/groups/#{group.id}/join.json" end.not_to change { group.users.count }

        expect(response).to be_forbidden
      end

      it "the join method is idempotent" do
        sign_in(user)

        expect do put "/groups/#{public_group.id}/join.json" end.to change {
          public_group.users.count
        }.by(1)
        expect(response.status).to eq(204)

        expect do put "/groups/#{public_group.id}/join.json" end.not_to change {
          public_group.users.count
        }
        expect(response.status).to eq(204)

        expect do put "/groups/#{public_group.id}/join.json" end.not_to change {
          public_group.users.count
        }
        expect(response.status).to eq(204)
      end
    end

    describe "#remove_member" do
      before { sign_in(admin) }

      it "cannot remove members from automatic groups" do
        group.update!(automatic: true)

        delete "/groups/#{group.id}/members.json", params: { user_id: 42 }
        expect(response.status).to eq(403)
      end

      it "raises an error if user to be removed is not found" do
        delete "/groups/#{group.id}/members.json", params: { user_id: -10 }
        expect(response.status).to eq(400)
      end

      it "returns skipped_usernames response body when removing a valid user but is not a member of that group" do
        delete "/groups/#{group.id}/members.json", params: { user_id: Discourse::SYSTEM_USER_ID }

        response_body = response.parsed_body
        expect(response.status).to eq(200)
        expect(response_body["usernames"]).to eq([])
        expect(response_body["skipped_usernames"].first).to eq("system")
      end

      context "when is able to remove a member" do
        it "removes by id" do
          expect do
            delete "/groups/#{group.id}/members.json", params: { user_id: user.id }
          end.to change { group.users.count }.by(-1)

          expect(response.status).to eq(200)
        end

        it "removes by id with integer in json" do
          expect do
            headers = { CONTENT_TYPE: "application/json" }
            delete "/groups/#{group.id}/members.json",
                   params: "{\"user_id\":#{user.id}}",
                   headers: headers
          end.to change { group.users.count }.by(-1)

          expect(response.status).to eq(200)
        end

        it "removes by username" do
          expect do
            delete "/groups/#{group.id}/members.json", params: { username: user.username }
          end.to change { group.users.count }.by(-1)

          expect(response.status).to eq(200)
        end

        it "removes user.primary_group_id when user is removed from group" do
          user.update!(primary_group_id: group.id)

          delete "/groups/#{group.id}/members.json", params: { user_id: user.id }

          expect(user.reload.primary_group_id).to eq(nil)
        end

        it "removes by user_email" do
          expect do
            delete "/groups/#{group.id}/members.json", params: { user_email: user.email }
          end.to change { group.users.count }.by(-1)

          expect(response.status).to eq(200)
        end

        context "with public group" do
          let(:group) { Fabricate(:public_group, users: [other_user]) }

          context "when admin" do
            it "removes by username" do
              expect do
                delete "/groups/#{group.id}/members.json", params: { username: other_user.username }
              end.to change { group.users.count }.by(-1)

              expect(response.status).to eq(200)
            end
          end

          it "should not allow a underprivileged user to leave a group for another user" do
            sign_in(user)

            delete "/groups/#{group.id}/members.json", params: { username: other_user.username }

            expect(response).to be_forbidden
          end
        end
      end

      describe "#remove_members" do
        context "when is able to remove several members from a group" do
          fab!(:user1) { Fabricate(:user) }
          fab!(:user2) { Fabricate(:user, username: "UsEr2") }
          let(:group1) { Fabricate(:group, users: [user1, user2]) }

          it "removes by username" do
            expect do
              delete "/groups/#{group1.id}/members.json",
                     params: {
                       usernames: [user1.username, user2.username.upcase].join(","),
                     }
            end.to change { group1.users.count }.by(-2)
            expect(response.status).to eq(200)
          end

          it "removes by id" do
            expect do
              delete "/groups/#{group1.id}/members.json",
                     params: {
                       user_ids: [user1.id, user2.id].join(","),
                     }
            end.to change { group1.users.count }.by(-2)

            expect(response.status).to eq(200)
          end

          it "removes by id with integer in json" do
            expect do
              headers = { CONTENT_TYPE: "application/json" }
              delete "/groups/#{group1.id}/members.json",
                     params: "{\"user_ids\":#{user1.id}}",
                     headers: headers
            end.to change { group1.users.count }.by(-1)

            expect(response.status).to eq(200)
          end

          it "removes by email" do
            expect do
              delete "/groups/#{group1.id}/members.json",
                     params: {
                       user_emails: [user1.email, user2.email].join(","),
                     }
            end.to change { group1.users.count }.by(-2)

            expect(response.status).to eq(200)
          end

          it "only removes users in that group" do
            delete "/groups/#{group1.id}/members.json",
                   params: {
                     usernames: [user.username, user2.username].join(","),
                   }

            response_body = response.parsed_body
            expect(response.status).to eq(200)
            expect(response_body["usernames"].first).to eq(user2.username)
            expect(response_body["skipped_usernames"].first).to eq(user.username)
          end
        end
      end
    end

    describe "#leave" do
      let(:group_with_public_exit) { Fabricate(:group, public_exit: true, users: [user]) }

      it "should allow a user to leave a group with public exit" do
        sign_in(user)

        expect do delete "/groups/#{group_with_public_exit.id}/leave.json" end.to change {
          group_with_public_exit.users.count
        }.by(-1)

        expect(response.status).to eq(204)
      end

      it "should not allow a user to leave a group without public exit" do
        sign_in(user)

        expect do delete "/groups/#{group.id}/leave.json" end.not_to change { group.users.count }

        expect(response).to be_forbidden
      end

      it "should not allow an anonymous user to call the leave method" do
        expect do delete "/groups/#{group_with_public_exit.id}/leave.json" end.not_to change {
          group_with_public_exit.users.count
        }

        expect(response).to be_forbidden
      end

      it "the leave method is idempotent" do
        sign_in(user)

        expect do delete "/groups/#{group_with_public_exit.id}/leave.json" end.to change {
          group_with_public_exit.users.count
        }.by(-1)
        expect(response.status).to eq(204)

        expect do delete "/groups/#{group_with_public_exit.id}/leave.json" end.not_to change {
          group_with_public_exit.users.count
        }
        expect(response.status).to eq(204)

        expect do delete "/groups/#{group_with_public_exit.id}/leave.json" end.not_to change {
          group_with_public_exit.users.count
        }
        expect(response.status).to eq(204)
      end
    end
  end

  describe "#handle_membership_request" do
    before do
      group.add_owner(user)
      sign_in(user)
    end

    it "sends a reply to the request membership topic when accepted" do
      GroupRequest.create!(group: group, user: other_user)

      # send the initial request PM
      PostCreator.new(
        other_user,
        title: I18n.t("groups.request_membership_pm.title", group_name: group.name),
        raw: "*British accent* Please, sir, may I have some group?",
        archetype: Archetype.private_message,
        target_usernames: user.username,
        skip_validations: true,
      ).create!

      topic = Topic.last

      expect {
        put "/groups/#{group.id}/handle_membership_request.json",
            params: {
              user_id: other_user.id,
              accept: true,
            }
      }.to_not change { Topic.count }

      expect(topic.archetype).to eq(Archetype.private_message)
      expect(Topic.first.title).to eq(
        I18n.t("groups.request_membership_pm.title", group_name: group.name),
      )

      post = Post.last
      expect(post.topic_id).to eq(Topic.last.id)
      expect(topic.posts.count).to eq(2)
      expect(post.raw).to eq(
        I18n.t("groups.request_accepted_pm.body", group_name: group.name).strip,
      )
    end

    it "sends accepted membership request reply even if request is in another language" do
      SiteSetting.allow_user_locale = true
      other_user.update!(locale: "fr")

      GroupRequest.create!(group: group, user: other_user)

      # send the initial request PM
      PostCreator.new(
        other_user,
        title: I18n.t("groups.request_membership_pm.title", group_name: group.name, locale: "fr"),
        raw: "*French accent* Please let me in!",
        archetype: Archetype.private_message,
        target_usernames: user.username,
        skip_validations: true,
      ).create!

      topic = Topic.last

      expect {
        put "/groups/#{group.id}/handle_membership_request.json",
            params: {
              user_id: other_user.id,
              accept: true,
            }
      }.to_not change { Topic.count }

      expect(topic.archetype).to eq(Archetype.private_message)
      expect(Topic.first.title).to eq(
        I18n.t("groups.request_membership_pm.title", group_name: group.name, locale: "fr"),
      )

      post = Post.last
      expect(post.topic_id).to eq(Topic.last.id)
      expect(topic.posts.count).to eq(2)
      expect(post.raw).to eq(
        I18n.t("groups.request_accepted_pm.body", group_name: group.name, locale: "fr").strip,
      )
    end

    it "works even though the user has no locale" do
      other_user.update!(locale: "")

      GroupRequest.create!(group: group, user: other_user)

      # send the initial request PM
      PostCreator.new(
        other_user,
        title: I18n.t("groups.request_membership_pm.title", group_name: group.name),
        raw: "*Alien accent* Can I join?!",
        archetype: Archetype.private_message,
        target_usernames: user.username,
        skip_validations: true,
      ).create!

      topic = Topic.last

      expect {
        put "/groups/#{group.id}/handle_membership_request.json",
            params: {
              user_id: other_user.id,
              accept: true,
            }
      }.to_not change { Topic.count }

      expect(topic.posts.count).to eq(2)
    end
  end

  describe "#histories" do
    context "when user is not signed in" do
      it "should raise the right error" do
        get "/groups/#{group.name}/logs.json"
        expect(response.status).to eq(403)
      end
    end

    context "when user is not a group owner" do
      before { sign_in(user) }

      it "should be forbidden" do
        get "/groups/#{group.name}/logs.json"

        expect(response).to be_forbidden
      end
    end

    describe "when user is a group owner" do
      before do
        group.add_owner(user)
        sign_in(user)
      end

      describe "when viewing a public group" do
        before do
          group.update!(public_admission: true, public_exit: true)

          GroupActionLogger.new(user, group).log_change_group_settings
        end

        it "should allow group owner to view history" do
          get "/groups/#{group.name}/logs.json"

          expect(response.status).to eq(200)

          result = response.parsed_body["logs"].find { |entry| entry["subject"] == "public_exit" }

          expect(result["action"]).to eq(GroupHistory.actions[1].to_s)
          expect(result["subject"]).to eq("public_exit")
          expect(result["prev_value"]).to eq("f")
          expect(result["new_value"]).to eq("t")
        end
      end

      it "should not be allowed to view history of an automatic group" do
        group = Group.find_by(id: Group::AUTO_GROUPS[:admins])

        get "/groups/#{group.name}/logs.json"

        expect(response.status).to eq(403)
      end
    end

    context "when user is an admin" do
      before { sign_in(admin) }

      it "should be able to view history" do
        GroupActionLogger.new(admin, group).log_remove_user_from_group(user)

        get "/groups/#{group.name}/logs.json"

        expect(response.status).to eq(200)

        result = response.parsed_body["logs"].first

        expect(result["action"]).to eq(GroupHistory.actions[3].to_s)
      end

      it "should be able to view history of automatic groups" do
        group = Group.find_by(id: Group::AUTO_GROUPS[:admins])

        get "/groups/#{group.name}/logs.json"

        expect(response.status).to eq(200)
      end

      it "should be able to filter through the history" do
        GroupActionLogger.new(admin, group).log_add_user_to_group(user)
        GroupActionLogger.new(admin, group).log_remove_user_from_group(user)

        get "/groups/#{group.name}/logs.json",
            params: {
              filters: {
                "action" => "add_user_to_group",
              },
            }

        expect(response.status).to eq(200)

        logs = response.parsed_body["logs"]

        expect(logs.count).to eq(1)
        expect(logs.first["action"]).to eq(GroupHistory.actions[2].to_s)
      end
    end
  end

  describe "#request_membership" do
    fab!(:new_user) { Fabricate(:user) }

    it "requires the user to log in" do
      post "/groups/#{group.name}/request_membership.json"
      expect(response.status).to eq(403)
    end

    it "requires a reason" do
      sign_in(user)

      post "/groups/#{group.name}/request_membership.json"
      expect(response.status).to eq(400)
    end

    it "checks for duplicates" do
      sign_in(user)

      post "/groups/#{group.name}/request_membership.json", params: { reason: "Please add me in" }

      expect(response.status).to eq(200)

      post "/groups/#{group.name}/request_membership.json", params: { reason: "Please add me in" }

      expect(response.status).to eq(409)
    end

    it "limits the character count of the reason" do
      sign_in(user)

      post "/groups/#{group.name}/request_membership.json",
           params: {
             reason: "x" * (GroupRequest::REASON_CHARACTER_LIMIT + 1),
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        "Reason is too long (maximum is 5000 characters)",
      )
    end

    it "should create the right PM" do
      owner1 = Fabricate(:user, last_seen_at: Time.zone.now)
      owner2 = Fabricate(:user, last_seen_at: Time.zone.now - 1.day)
      [owner1, owner2].each { |owner| group.add_owner(owner) }

      sign_in(user)

      post "/groups/#{group.name}/request_membership.json", params: { reason: "Please add me in" }

      expect(response.status).to eq(200)

      post = Post.last
      topic = post.topic
      body = response.parsed_body

      expect(body["relative_url"]).to eq(topic.relative_url)
      expect(post.topic.custom_fields["requested_group_id"].to_i).to eq(group.id)
      expect(post.user).to eq(user)

      expect(topic.title).to eq(
        I18n.t("groups.request_membership_pm.title", group_name: group.name),
      )

      expect(post.raw).to start_with("Please add me in")
      expect(topic.archetype).to eq(Archetype.private_message)
      expect(topic.allowed_users).to contain_exactly(user, owner1, owner2)
      expect(topic.allowed_groups).to eq([])
    end
  end

  describe "#search " do
    fab!(:hidden_group) do
      Fabricate(:group, visibility_level: Group.visibility_levels[:owners], name: "KingOfTheNorth")
    end

    before do
      group.update!(
        name: "GOT",
        full_name: "Daenerys Targaryen",
        visibility_level: Group.visibility_levels[:logged_on_users],
      )

      hidden_group
    end

    context "as an anon user" do
      it "returns the right response" do
        get "/groups/search.json"
        expect(response.status).to eq(403)
      end
    end

    context "as a normal user" do
      it "returns the right response" do
        sign_in(user)

        get "/groups/search.json"

        expect(response.status).to eq(200)
        groups = response.parsed_body

        expected_ids = Group::AUTO_GROUPS.map { |name, id| id }
        expected_ids.delete(Group::AUTO_GROUPS[:everyone])
        expected_ids << group.id

        expect(groups.map { |group| group["id"] }).to contain_exactly(*expected_ids)

        %w[GO nerys].each do |term|
          get "/groups/search.json?term=#{term}"

          expect(response.status).to eq(200)
          groups = response.parsed_body

          expect(groups.length).to eq(1)
          expect(groups.first["id"]).to eq(group.id)
        end

        get "/groups/search.json?term=KingOfTheNorth"

        expect(response.status).to eq(200)
        groups = response.parsed_body

        expect(groups).to eq([])
      end
    end

    context "as a group owner" do
      before { hidden_group.add_owner(user) }

      it "returns the right response" do
        sign_in(user)

        get "/groups/search.json?term=north"

        expect(response.status).to eq(200)
        groups = response.parsed_body

        expect(groups.length).to eq(1)
        expect(groups.first["id"]).to eq(hidden_group.id)
      end
    end

    context "as an admin" do
      it "returns the right response" do
        sign_in(admin)

        get "/groups/search.json?ignore_automatic=true"

        expect(response.status).to eq(200)
        groups = response.parsed_body

        expect(groups.length).to eq(2)

        expect(groups.map { |group| group["id"] }).to contain_exactly(group.id, hidden_group.id)
      end
    end

    describe "groups_search_query modifier" do
      fab!(:user)
      fab!(:cool_group) { Fabricate(:group, name: "cool-group") }
      fab!(:boring_group) { Fabricate(:group, name: "boring-group") }

      before { sign_in(user) }

      it "allows changing the query" do
        get "/groups/search.json", params: { term: "cool" }
        expect(response.status).to eq(200)
        expect(response.parsed_body.map { |g| g["id"] }).to include(cool_group.id)
        expect(response.parsed_body.map { |g| g["id"] }).not_to include(boring_group.id)

        Plugin::Instance
          .new
          .register_modifier(:groups_search_query) do |query|
            query.where("groups.name LIKE 'boring%'")
          end

        get "/groups/search.json", params: { term: "cool" }
        expect(response.status).to eq(200)
        expect(response.parsed_body.map { |g| g["id"] }).not_to include(
          cool_group.id,
          boring_group.id,
        )
      ensure
        DiscoursePluginRegistry.clear_modifiers!
      end
    end
  end

  describe "#new" do
    describe "for an anon user" do
      it "should return 404" do
        get "/groups/custom/new"

        expect(response.status).to eq(404)
      end
    end

    describe "for a normal user" do
      before { sign_in(user) }

      it "should return 404" do
        get "/groups/custom/new"

        expect(response.status).to eq(404)
      end
    end

    describe "for an admin user" do
      before { sign_in(admin) }

      it "should return 200" do
        get "/groups/custom/new"

        expect(response.status).to eq(200)
      end
    end
  end

  describe "#check_name" do
    describe "for an anon user" do
      it "should return the right response" do
        get "/groups/check-name.json", params: { group_name: "test" }
        expect(response.status).to eq(403)
      end
    end

    it "should return the right response" do
      sign_in(Fabricate(:user))
      SiteSetting.reserved_usernames = "test|donkey"
      get "/groups/check-name.json", params: { group_name: "test" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["available"]).to eq(true)
    end
  end

  describe "#permissions" do
    before { sign_in(other_user) }

    it "ensures the group can be seen" do
      group.update!(visibility_level: Group.visibility_levels[:owners])

      get "/groups/#{group.name}/permissions.json"

      expect(response.status).to eq(404)
    end

    describe "with varying category permissions" do
      fab!(:category)

      before do
        category.set_permissions("#{group.name}": :full)
        category.save!
      end

      it "does not return categories the user cannot see" do
        get "/groups/#{group.name}/permissions.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body).to eq([])
      end

      it "returns categories the user can see" do
        group.add(other_user)

        get "/groups/#{group.name}/permissions.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.count).to eq(1)
        expect(response.parsed_body.first["category"]["id"]).to eq(category.id)
      end
    end

    it "returns categories alphabetically" do
      sign_in(user)

      ["Three", "New Cat", "Abc", "Hello"].each do |name|
        category = Fabricate(:category, name: name)
        category.set_permissions("#{group.name}": :full)
        category.save!
      end

      get "/groups/#{group.name}/permissions.json"

      expect(response.status).to eq(200)

      expect(response.parsed_body.map { |permission| permission["category"]["name"] }).to eq(
        ["Abc", "Hello", "New Cat", "Three"],
      )
    end
  end

  describe "#test_email_settings" do
    let(:params) do
      {
        protocol: protocol,
        ssl_mode: ssl_mode,
        ssl: ssl,
        port: port,
        host: host,
        username: username,
        password: password,
      }
    end

    before do
      sign_in(user)
      group.group_users.where(user: user).last.update(owner: user)
    end

    context "when validating smtp" do
      let(:protocol) { "smtp" }
      let(:username) { "test@gmail.com" }
      let(:password) { "password" }
      let(:domain) { nil }
      let(:ssl_mode) { Group.smtp_ssl_modes[:starttls] }
      let(:ssl) { nil }
      let(:host) { "smtp.somemailsite.com" }
      let(:port) { 587 }

      context "when an error is raised" do
        before do
          EmailSettingsValidator.expects(:validate_smtp).raises(
            Net::SMTPAuthenticationError,
            "Invalid credentials",
          )
        end
        it "uses the friendly error message functionality to return the message to the user" do
          post "/groups/#{group.id}/test_email_settings.json", params: params
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("email_settings.smtp_authentication_error", message: "Invalid credentials"),
          )
        end
      end
    end

    context "when validating imap" do
      let(:protocol) { "imap" }
      let(:username) { "test@gmail.com" }
      let(:password) { "password" }
      let(:domain) { nil }
      let(:ssl) { true }
      let(:ssl_mode) { nil }
      let(:host) { "imap.somemailsite.com" }
      let(:port) { 993 }

      it "validates with the correct TLS settings" do
        EmailSettingsValidator.expects(:validate_imap).with(has_entries(ssl: true))
        post "/groups/#{group.id}/test_email_settings.json", params: params
        expect(response.status).to eq(200)
      end

      context "when an error is raised" do
        before do
          EmailSettingsValidator.expects(:validate_imap).raises(
            Net::IMAP::NoResponseError,
            stub(data: stub(text: "Invalid credentials")),
          )
        end
        it "uses the friendly error message functionality to return the message to the user" do
          post "/groups/#{group.id}/test_email_settings.json", params: params
          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"]).to include(
            I18n.t("email_settings.imap_authentication_error"),
          )
        end
      end
    end

    describe "global param validation and rate limit" do
      let(:protocol) { "smtp" }
      let(:host) { "smtp.gmail.com" }
      let(:port) { 587 }
      let(:username) { "test@gmail.com" }
      let(:password) { "password" }
      let(:ssl) { true }
      let(:ssl_mode) { nil }

      context "when the protocol is not accepted" do
        let(:protocol) { "sigma" }
        it "raises an invalid params error" do
          post "/groups/#{group.id}/test_email_settings.json", params: params
          expect(response.status).to eq(400)
          expect(response.parsed_body["errors"].first).to match(
            /Valid protocols to test are smtp and imap/,
          )
        end
      end

      context "when user does not have access to the group" do
        before { group.group_users.destroy_all }
        it "errors if the user does not have access to the group" do
          post "/groups/#{group.id}/test_email_settings.json", params: params

          expect(response.status).to eq(403)
        end
      end

      context "when rate limited" do
        it "rate limits anon searches per user" do
          RateLimiter.enable

          5.times { post "/groups/#{group.id}/test_email_settings.json", params: params }
          post "/groups/#{group.id}/test_email_settings.json", params: params
          expect(response.status).to eq(429)
        end
      end
    end
  end
end
