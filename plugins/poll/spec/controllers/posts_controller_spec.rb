# frozen_string_literal: true

require "rails_helper"

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
      expect(Poll.exists?(post_id: json["id"])).to eq(true)
    end

    it "works on any post" do
      post_1 = Fabricate(:post)

      post :create, params: {
        topic_id: post_1.topic.id, raw: "[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(Poll.exists?(post_id: json["id"])).to eq(true)
    end

    it "schedules auto-close job" do
      freeze_time
      name = "auto_close"
      close_date = 1.month.from_now

      expect do
        post :create, params: {
          title: title,
          raw: "[poll name=#{name} close=#{close_date.iso8601}]\n- A\n- B\n[/poll]"
        }, format: :json
      end.to change { Jobs::ClosePoll.jobs.size }.by(1) &
             change { Poll.count }.by(1)

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      post_id = json["id"]

      expect(Poll.find_by(post_id: post_id).close_at).to be_within_one_second_of(1.month.from_now)

      job = Jobs::ClosePoll.jobs.first
      job_args = job["args"].first

      expect(job_args["post_id"]).to eq(post_id)
      expect(job_args["poll_name"]).to eq(name)
    end

    it "should have different options" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n- A\n[/poll]"
      }, format: :json

      expect(response).not_to be_successful
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_different_options"))
    end

    it "should have at least 1 options" do
      post :create, params: {
        title: title, raw: "[poll]\n[/poll]"
      }, format: :json

      expect(response).not_to be_successful
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_at_least_1_option"))
    end

    it "should have at most 'SiteSetting.poll_maximum_options' options" do
      raw = +"[poll]\n"
      (SiteSetting.poll_maximum_options + 1).times { |n| raw << "\n- #{n}" }
      raw << "\n[/poll]"

      post :create, params: {
        title: title, raw: raw
      }, format: :json

      expect(response).not_to be_successful
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_less_options", count: SiteSetting.poll_maximum_options))
    end

    it "should have valid parameters" do
      post :create, params: {
        title: title, raw: "[poll type=multiple min=5]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_successful
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
      expect(Poll.find_by(post_id: json["id"]).name).to eq("&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;")
    end

    it "also works whe there is a link starting with '[poll'" do
      post :create, params: {
        title: title, raw: "[Polls are awesome](/foobar)\n[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(Poll.exists?(post_id: json["id"])).to eq(true)
    end

    it "prevents pollception" do
      post :create, params: {
        title: title, raw: "[poll name=1]\n- A\n[poll name=2]\n- B\n- C\n[/poll]\n- D\n[/poll]"
      }, format: :json

      expect(response.status).to eq(200)
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(Poll.where(post_id: json["id"]).count).to eq(1)
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
          expect(json["post"]["polls"][0]["options"][2]["html"]).to eq("C")
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

          it "can change the options" do
            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response.status).to eq(200)
            json = ::JSON.parse(response.body)
            expect(json["post"]["polls"][0]["options"][1]["html"]).to eq("C")
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

          it "cannot change the options" do
            put :update, params: {
              id: post_id, post: { raw: new_option }
            }, format: :json

            expect(response).not_to be_successful
            json = ::JSON.parse(response.body)
            expect(json["errors"][0]).to eq(I18n.t(
              "poll.edit_window_expired.cannot_edit_default_poll_with_votes",
              minutes: poll_edit_window_mins
            ))
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

      expect(response).not_to be_successful
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.named_poll_must_have_different_options", name: "foo"))
    end

    it "should have at least 1 option" do
      post :create, params: {
        title: title, raw: "[poll name='foo']\n[/poll]"
      }, format: :json

      expect(response).not_to be_successful
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.named_poll_must_have_at_least_1_option", name: "foo"))
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
      expect(Poll.where(post_id: json["id"]).count).to eq(2)
    end

    it "should have a name" do
      post :create, params: {
        title: title, raw: "[poll]\n- A\n- B\n[/poll]\n[poll]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_successful
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.multiple_polls_without_name"))
    end

    it "should have unique name" do
      post :create, params: {
        title: title, raw: "[poll name=foo]\n- A\n- B\n[/poll]\n[poll name=foo]\n- A\n- B\n[/poll]"
      }, format: :json

      expect(response).not_to be_successful
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

      expect(response).not_to be_successful
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
      expect(Poll.exists?(post_id: json["id"])).to eq(true)
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
      expect(Poll.exists?(post_id: json["id"])).to eq(true)
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
      expect(Poll.exists?(post_id: json["id"])).to eq(true)
    end
  end
end
