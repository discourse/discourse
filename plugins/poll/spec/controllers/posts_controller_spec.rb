require "rails_helper"
require_relative "../helpers"

describe PostsController do
  let!(:user) { log_in }
  let!(:title) { "Testing Poll Plugin" }

  before do
    SiteSetting.min_first_post_typing_time = 0
  end

  describe "polls" do

    it "works" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end

    it "works on any post" do
      post_1 = Fabricate(:post)

      post :create, params: {
        topic_id: post_1.topic.id, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end

    it "schedules auto-close job" do
      name = "auto_close"
      close_date = 1.month.from_now

      post :create, params: {
        title: title, raw: "[poll name=#{name} close=#{close_date.iso8601}]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["polls"][name]["close"]).to be

      expect(Jobs.scheduled_for(:close_poll, post_id: Post.last.id, poll_name: name)).to be
    end

    it "should have different options" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n- A\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_different_options"))
    end

    it "should have at least 2 options" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_at_least_2_options"))
    end

    it "should have at most 'SiteSetting.poll_maximum_options' options" do
      raw = "[poll]\n"
      (SiteSetting.poll_maximum_options + 1).times { |n| raw << "\n- #{n}" }
      raw << "\n[/poll]"

      post :create, params: {
        title: title, raw: raw
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_less_options", count: SiteSetting.poll_maximum_options))
    end

    it "should have valid parameters" do
      post :create, params: {
        title: title, raw: "[poll type=multiple min=5]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters"))
    end

    it "prevents self-xss" do
      post :create, params: {
        title: title, raw: "[poll name=<script>alert('xss')</script>]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["cooked"]).to include("&lt;script&gt;")
      expect(json["polls"]["&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;"]).to be
    end

    it "also works whe there is a link starting with '[poll'" do
      post :create, params: {
        title: title, raw: "[Polls are awesome](/foobar)\n[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]).to be
    end

    it "prevents pollception" do
      post :create, params: {
        title: title, raw: "[poll name=1]\n- A\n[poll name=2]\n- B\n- C\n[/poll]\n- D\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["1"]).to_not be
      expect(json["polls"]["2"]).to be
    end

    describe "edit window" do

      describe "within the first 5 minutes" do

        let(:post_id) do
          freeze_time(4.minutes.ago) do
            post :create, params: {
              title: title, raw: "[poll]\n- A\n- B\n[/poll]"
            }, format: :json

            ::JSON.parse(response.body)["id"]
          end
        end

        it "can be changed" do
          put :update, params: {
            id: post_id, post: { raw: "[poll]\n- A\n- B\n- C\n[/poll]" }
          }, format: :json

          expect(response.status).to eq(200)
          json = ::JSON.parse(response.body)
          expect(json["post"]["polls"]["poll"]["options"][2]["html"]).to eq("C")
        end

        it "resets the votes" do
          DiscoursePoll::Poll.vote(post_id, "poll", ["5c24fc1df56d764b550ceae1b9319125"], user)

          put :update, params: {
            id: post_id, post: { raw: "[poll]\n- A\n- B\n- C\n[/poll]" }
          }, format: :json

          expect(response.status).to eq(200)
          json = ::JSON.parse(response.body)
          expect(json["post"]["polls_votes"]).to_not be
        end

      end

      describe "after the poll edit window has expired" do

        let(:poll) { "[poll]\n- A\n- B\n[/poll]" }
        let(:new_option) { "[poll]\n- A\n- C\n[/poll]" }
        let(:updated) { "before\n\n[poll]\n- A\n- B\n[/poll]\n\nafter" }

        let(:post_id) do
          freeze_time(6.minutes.ago) do
            post :create, params: {
              title: title, raw: poll
            }, format: :json

            ::JSON.parse(response.body)["id"]
          end
        end

        let(:poll_edit_window_mins) { 6 }

        before do
          SiteSetting.poll_edit_window_mins = poll_edit_window_mins
        end

        describe "with no vote" do

          it "OP can change the options" do
            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response.status).to eq(200)
            json = ::JSON.parse(response.body)
            expect(json["post"]["polls"]["poll"]["options"][1]["html"]).to eq("C")
          end

          it "staff can change the options" do
            log_in_user(Fabricate(:moderator))

            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response.status).to eq(200)
            json = ::JSON.parse(response.body)
            expect(json["post"]["polls"]["poll"]["options"][1]["html"]).to eq("C")
          end

          it "support changes on the post" do
            put :update, params: { id: post_id, post: { raw: updated } }, format: :json
            expect(response.status).to eq(200)
            json = ::JSON.parse(response.body)
            expect(json["post"]["cooked"]).to match("before")
          end

        end

        describe "with at least one vote" do

          before do
            DiscoursePoll::Poll.vote(post_id, "poll", ["5c24fc1df56d764b550ceae1b9319125"], user)
          end

          it "OP cannot change the options" do
            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response).not_to be_success
            json = ::JSON.parse(response.body)
            expect(json["errors"][0]).to eq(I18n.t(
              "poll.edit_window_expired.op_cannot_edit_options",
              minutes: poll_edit_window_mins
            ))
          end

          it "staff can change the options and votes are merged" do
            log_in_user(Fabricate(:moderator))

            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response.status).to eq(200)
            json = ::JSON.parse(response.body)
            expect(json["post"]["polls"]["poll"]["options"][1]["html"]).to eq("C")
            expect(json["post"]["polls"]["poll"]["voters"]).to eq(1)
            expect(json["post"]["polls"]["poll"]["options"][0]["votes"]).to eq(1)
            expect(json["post"]["polls"]["poll"]["options"][1]["votes"]).to eq(0)
          end

          it "staff can change the options and anonymous votes are merged" do
            post = Post.find_by(id: post_id)
            default_poll = post.custom_fields["polls"]["poll"]
            add_anonymous_votes(post, default_poll, 7, "5c24fc1df56d764b550ceae1b9319125" => 7)

            log_in_user(Fabricate(:moderator))

            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response.status).to eq(200)

            json = ::JSON.parse(response.body)
            expect(json["post"]["polls"]["poll"]["options"][1]["html"]).to eq("C")
            expect(json["post"]["polls"]["poll"]["voters"]).to eq(8)
            expect(json["post"]["polls"]["poll"]["options"][0]["votes"]).to eq(8)
            expect(json["post"]["polls"]["poll"]["options"][1]["votes"]).to eq(0)
          end

          it "support changes on the post" do
            put :update, params: { id: post_id, post: { raw: updated } }, format: :json
            expect(response.status).to eq(200)
            json = ::JSON.parse(response.body)
            expect(json["post"]["cooked"]).to match("before")
          end

        end

      end

    end

  end

  describe "named polls" do

    it "should have different options" do
      post :create, params: {
        title: title, raw: "[poll name=""foo""]\n- A\n- A\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.named_poll_must_have_different_options", name: "foo"))
    end

    it "should have at least 2 options" do
      post :create, params: {
        title: title, raw: "[poll name='foo']\n- A\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.named_poll_must_have_at_least_2_options", name: "foo"))
    end

  end

  describe "multiple polls" do

    it "works" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]\n[poll name=foo]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
      expect(json["polls"]["foo"]).to be
    end

    it "should have a name" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]\n[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.multiple_polls_without_name"))
    end

    it "should have unique name" do
      post :create, params: {
        title: title, raw: "[poll name=foo]\n- A\n- B\n[/poll]\n[poll name=foo]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.multiple_polls_with_same_name", name: "foo"))
    end

  end

  describe "disabled polls" do
    before do
      SiteSetting.poll_enabled = false
    end

    it "doesn’t cook the poll" do
      log_in_user(Fabricate(:user, admin: true, trust_level: 4))

      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to eq("<p>[poll]</p>\n<ul>\n<li>A</li>\n<li>B<br>\n[/poll]</li>\n</ul>")
    end
  end

  describe "regular user with insufficient trust level" do
    before do
      SiteSetting.poll_minimum_trust_level_to_create = 2
    end

    it "invalidates the post" do
      log_in_user(Fabricate(:user, trust_level: 1))

      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.insufficient_rights_to_create"))
    end
  end

  describe "regular user with equal trust level" do
    before do
      SiteSetting.poll_minimum_trust_level_to_create = 2
    end

    it "validates the post" do
      log_in_user(Fabricate(:user, trust_level: 2))

      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end
  end

  describe "regular user with superior trust level" do
    before do
      SiteSetting.poll_minimum_trust_level_to_create = 2
    end

    it "validates the post" do
      log_in_user(Fabricate(:user, trust_level: 3))

      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end
  end

  describe "staff with insufficient trust level" do
    before do
      SiteSetting.poll_minimum_trust_level_to_create = 2
    end

    it "validates the post" do
      log_in_user(Fabricate(:user, moderator: true, trust_level: 1))

      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end
  end
end
