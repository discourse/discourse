require "spec_helper"

describe PostsController do
  let!(:user) { log_in }
  let!(:title) { "Testing Poll Plugin" }

  before do
    SiteSetting.min_first_post_typing_time = 0
  end

  describe "polls" do

    it "works" do
      xhr :post, :create, { title: title, raw: "[poll]\n- A\n- B\n[/poll]" }
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end

    it "works on any post" do
      post = Fabricate(:post)
      xhr :post, :create, { topic_id: post.topic.id, raw: "[poll]\n- A\n- B\n[/poll]" }
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
    end

    it "should have different options" do
      xhr :post, :create, { title: title, raw: "[poll]\n- A\n- A[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_different_options"))
    end

    it "should have at least 2 options" do
      xhr :post, :create, { title: title, raw: "[poll]\n- A[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_at_least_2_options"))
    end

    it "should have at most 'SiteSetting.poll_maximum_options' options" do
      raw = "[poll]"
      (SiteSetting.poll_maximum_options + 1).times { |n| raw << "\n- #{n}" }
      raw << "[/poll]"

      xhr :post, :create, { title: title, raw: raw }

      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_must_have_less_options", max: SiteSetting.poll_maximum_options))
    end

    it "should have valid parameters" do
      xhr :post, :create, { title: title, raw: "[poll type=multiple min=5]\n- A\n- B[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters"))
    end

    it "prevents self-xss" do
      xhr :post, :create, { title: title, raw: "[poll name=<script>alert('xss')</script>]\n- A\n- B\n[/poll]" }
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["&lt;script&gt;alert(xss)&lt;/script&gt;"]).to be
    end

    it "also works whe there is a link starting with '[poll'" do
      xhr :post, :create, { title: title, raw: "[Polls are awesome](/foobar)\n[poll]\n- A\n- B\n[/poll]" }
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]).to be
    end

    it "prevents pollception" do
      xhr :post, :create, { title: title, raw: "[poll name=1]\n- A\n[poll name=2]\n- B\n- C\n[/poll]\n- D\n[/poll]" }
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["1"]).to_not be
      expect(json["polls"]["2"]).to be
    end

    describe "edit window" do

      describe "within the first 5 minutes" do

        let(:post_id) do
          Timecop.freeze(4.minutes.ago) do
            xhr :post, :create, { title: title, raw: "[poll]\n- A\n- B\n[/poll]" }
            ::JSON.parse(response.body)["id"]
          end
        end

        it "can be changed" do
          xhr :put, :update, { id: post_id, post: { raw: "[poll]\n- A\n- B\n- C\n[/poll]" } }
          expect(response).to be_success
          json = ::JSON.parse(response.body)
          expect(json["post"]["polls"]["poll"]["options"][2]["html"]).to eq("C")
        end

        it "resets the votes" do
          DiscoursePoll::Poll.vote(post_id, "poll", ["5c24fc1df56d764b550ceae1b9319125"], user.id)
          xhr :put, :update, { id: post_id, post: { raw: "[poll]\n- A\n- B\n- C\n[/poll]" } }
          expect(response).to be_success
          json = ::JSON.parse(response.body)
          expect(json["post"]["polls_votes"]).to_not be
        end

      end

      describe "after the first 5 minutes" do

        let(:poll) { "[poll]\n- A\n- B[/poll]" }
        let(:new_option) { "[poll]\n- A\n- C[/poll]" }
        let(:updated) { "before\n\n[poll]\n- A\n- B[/poll]\n\nafter" }

        let(:post_id) do
          Timecop.freeze(6.minutes.ago) do
            xhr :post, :create, { title: title, raw: poll }
            ::JSON.parse(response.body)["id"]
          end
        end

        it "OP cannot change the options" do
          xhr :put, :update, { id: post_id, post: { raw: new_option } }
          expect(response).not_to be_success
          json = ::JSON.parse(response.body)
          expect(json["errors"][0]).to eq(I18n.t("poll.op_cannot_edit_options_after_5_minutes"))
        end

        it "staff can change the options" do
          log_in_user(Fabricate(:moderator))
          xhr :put, :update, { id: post_id, post: { raw: new_option } }
          expect(response).to be_success
          json = ::JSON.parse(response.body)
          expect(json["post"]["polls"]["poll"]["options"][1]["html"]).to eq("C")
        end

        it "support changes on the post" do
          xhr :put, :update, { id: post_id, post: { raw: updated } }
          expect(response).to be_success
          json = ::JSON.parse(response.body)
          expect(json["post"]["cooked"]).to match("before")
        end

        describe "with at least one vote" do

          before do
            DiscoursePoll::Poll.vote(post_id, "poll", ["5c24fc1df56d764b550ceae1b9319125"], user.id)
          end

          it "support changes on the post" do
            xhr :put, :update, { id: post_id, post: { raw: updated } }
            expect(response).to be_success
            json = ::JSON.parse(response.body)
            expect(json["post"]["cooked"]).to match("before")
          end

        end

      end

    end

  end

  describe "named polls" do

    it "should have different options" do
      xhr :post, :create, { title: title, raw: "[poll name=""foo""]\n- A\n- A[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.named_poll_must_have_different_options", name: "foo"))
    end

    it "should have at least 2 options" do
      xhr :post, :create, { title: title, raw: "[poll name='foo']\n- A[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.named_poll_must_have_at_least_2_options", name: "foo"))
    end

  end

  describe "multiple polls" do

    it "works" do
      xhr :post, :create, { title: title, raw: "[poll]\n- A\n- B\n[/poll]\n[poll name=foo]\n- A\n- B\n[/poll]" }
      expect(response).to be_success
      json = ::JSON.parse(response.body)
      expect(json["cooked"]).to match("data-poll-")
      expect(json["polls"]["poll"]).to be
      expect(json["polls"]["foo"]).to be
    end

    it "should have a name" do
      xhr :post, :create, { title: title, raw: "[poll]\n- A\n- B\n[/poll]\n[poll]\n- A\n- B\n[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.multiple_polls_without_name"))
    end

    it "should have unique name" do
      xhr :post, :create, { title: title, raw: "[poll name=foo]\n- A\n- B\n[/poll]\n[poll name=foo]\n- A\n- B\n[/poll]" }
      expect(response).not_to be_success
      json = ::JSON.parse(response.body)
      expect(json["errors"][0]).to eq(I18n.t("poll.multiple_polls_with_same_name", name: "foo"))
    end

  end

end
