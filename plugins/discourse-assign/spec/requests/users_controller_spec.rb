# frozen_string_literal: true

RSpec.describe UsersController do
  fab!(:admin)
  fab!(:assignee) { Fabricate(:user, username: "assigneduser") }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = Group::AUTO_GROUPS[:staff].to_s
    sign_in(admin)
  end

  describe "#bookmarks" do
    fab!(:topic) { Fabricate(:read_topic, current_user: admin) }

    context "when a bookmarked topic has an active assignment" do
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic) }
      fab!(:assignment) { Fabricate(:topic_assignment, topic: topic, assigned_to: assignee) }

      it "includes the user assigned to the topic" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(
          response.parsed_body.dig("user_bookmark_list", "bookmarks", 0, "assigned_to_user", "id"),
        ).to eq(assignee.id)
      end
    end

    context "when a bookmarked topic's assignment is inactive" do
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic) }

      fab!(:assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: assignee, active: false)
      end

      it "does not include an assigned user" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("user_bookmark_list", "bookmarks", 0)).not_to have_key(
          "assigned_to_user",
        )
      end
    end

    context "when only a post in the bookmarked topic is assigned" do
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic) }

      fab!(:assignment) do
        Fabricate(:post_assignment, post: topic.first_post, assigned_to: assignee)
      end

      it "does not include an assigned user" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("user_bookmark_list", "bookmarks", 0)).not_to have_key(
          "assigned_to_user",
        )
      end
    end

    context "when a bookmarked post has an active assignment" do
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic.first_post) }

      fab!(:assignment) do
        Fabricate(:post_assignment, post: topic.first_post, assigned_to: assignee)
      end

      it "includes the user assigned to the post" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(
          response.parsed_body.dig("user_bookmark_list", "bookmarks", 0, "assigned_to_user", "id"),
        ).to eq(assignee.id)
      end
    end

    context "when a bookmarked post's assignment is inactive" do
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic.first_post) }

      fab!(:assignment) do
        Fabricate(:post_assignment, post: topic.first_post, assigned_to: assignee, active: false)
      end

      it "does not include an assigned user" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("user_bookmark_list", "bookmarks", 0)).not_to have_key(
          "assigned_to_user",
        )
      end
    end

    context "when only the topic of a bookmarked post is assigned" do
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic.first_post) }
      fab!(:assignment) { Fabricate(:topic_assignment, topic: topic, assigned_to: assignee) }

      it "does not include an assigned user" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("user_bookmark_list", "bookmarks", 0)).not_to have_key(
          "assigned_to_user",
        )
      end
    end

    context "when a different post in the bookmarked post's topic is assigned" do
      fab!(:other_post) { Fabricate(:post, topic: topic) }
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic.first_post) }
      fab!(:assignment) { Fabricate(:post_assignment, post: other_post, assigned_to: assignee) }

      it "does not include an assigned user" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("user_bookmark_list", "bookmarks", 0)).not_to have_key(
          "assigned_to_user",
        )
      end
    end

    context "when a bookmarked post and its topic are both assigned" do
      fab!(:topic_assignee) { Fabricate(:user, username: "topicassignee") }
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic.first_post) }

      fab!(:topic_assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: topic_assignee)
      end

      fab!(:post_assignment) do
        Fabricate(:post_assignment, post: topic.first_post, assigned_to: assignee)
      end

      it "includes the user assigned to the post" do
        get "/u/#{admin.username}/bookmarks.json"

        expect(response.status).to eq(200)
        expect(
          response.parsed_body.dig("user_bookmark_list", "bookmarks", 0, "assigned_to_user", "id"),
        ).to eq(assignee.id)
      end
    end
  end

  describe "#user_menu_bookmarks" do
    context "when a bookmarked topic's assignment is inactive" do
      fab!(:topic) { Fabricate(:read_topic, current_user: admin) }
      fab!(:bookmark) { Fabricate(:bookmark, user: admin, bookmarkable: topic) }

      fab!(:assignment) do
        Fabricate(:topic_assignment, topic: topic, assigned_to: assignee, active: false)
      end

      it "does not include an assigned user" do
        get "/u/#{admin.username}/user-menu-bookmarks"

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("bookmarks", 0)).not_to have_key("assigned_to_user")
      end
    end
  end
end
