# frozen_string_literal: true

RSpec.describe ComposerMessagesController do
  fab!(:topic) { Fabricate(:topic, created_at: 10.years.ago, last_posted_at: 10.years.ago) }
  fab!(:post) { Fabricate(:post, topic: topic, post_number: 1, created_at: 10.years.ago) }

  describe "#index" do
    it "requires you to be logged in" do
      get "/composer_messages.json"
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      let!(:user) { sign_in(Fabricate(:user)) }
      let(:args) do
        { "topic_id" => post.topic.id, "post_id" => "333", "composer_action" => "reply" }
      end

      it "redirects to your user preferences" do
        get "/composer_messages.json"
        expect(response.status).to eq(200)
      end

      it "delegates args to the finder" do
        user.user_stat.update!(post_count: 10)
        SiteSetting.disable_avatar_education_message = true

        get "/composer_messages.json", params: args
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["composer_messages"].first["id"]).to eq("reviving_old")
      end
    end
  end

  describe "#user_not_seen_in_a_while" do
    fab!(:user_1) { Fabricate(:user, last_seen_at: 3.years.ago) }
    fab!(:user_2) { Fabricate(:user, last_seen_at: 2.years.ago) }
    fab!(:user_3) { Fabricate(:user, last_seen_at: 6.months.ago) }

    it "requires you to be logged in" do
      get "/composer_messages/user_not_seen_in_a_while.json",
          params: {
            usernames: [user_1.username, user_2.username, user_3.username],
          }
      expect(response.status).to eq(403)
    end

    context "when logged in" do
      let!(:user) { sign_in(Fabricate(:user)) }

      before { SiteSetting.pm_warn_user_last_seen_months_ago = 24 }

      it "requires usernames parameter to be present" do
        get "/composer_messages/user_not_seen_in_a_while.json"
        expect(response.status).to eq(400)
      end

      it "returns users that have not been seen recently" do
        get "/composer_messages/user_not_seen_in_a_while.json",
            params: {
              usernames: [user_1.username, user_2.username, user_3.username],
            }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["user_count"]).to eq(2)
        expect(json["usernames"]).to contain_exactly(user_1.username, user_2.username)
      end

      it "accounts for pm_warn_user_last_seen_months_ago site setting" do
        SiteSetting.pm_warn_user_last_seen_months_ago = 30
        get "/composer_messages/user_not_seen_in_a_while.json",
            params: {
              usernames: [user_1.username, user_2.username, user_3.username],
            }
        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json["user_count"]).to eq(1)
        expect(json["usernames"]).to contain_exactly(user_1.username)
      end
    end
  end
end
