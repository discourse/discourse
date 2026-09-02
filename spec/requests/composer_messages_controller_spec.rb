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
        get "/composer_messages.json", params: args
        expect(response.status).to eq(200)

        json = response.parsed_body
        expect(json["composer_messages"].first["id"]).to eq("education")
      end

      it "does not include links from hidden posts in duplicate_lookup" do
        reply =
          Fabricate(
            :post,
            topic: topic,
            user: Fabricate(:user, refresh_auto_groups: true),
            raw: "Check out https://example.com/private-doc for details",
          )
        TopicLink.extract_from(reply)
        reply.hide!(PostActionType.types[:spam])

        get "/composer_messages.json", params: { topic_id: topic.id, composer_action: "reply" }
        expect(response.status).to eq(200)

        json = response.parsed_body
        duplicate_lookup = json["extras"]["duplicate_lookup"]
        expect(duplicate_lookup).not_to have_key("example.com/private-doc")
      end

      it "does not include restricted internal links in duplicate_lookup" do
        user.change_trust_level!(TrustLevel[1])
        restricted_category = Fabricate(:category)
        restricted_category.set_permissions(staff: :full)
        restricted_category.save!
        restricted_topic =
          Fabricate(:topic, category: restricted_category, title: "Secured category secret title")
        Fabricate(:post, topic: restricted_topic, user: restricted_topic.user)
        private_message = Fabricate(:private_message_topic, title: "Private message secret title")
        Fabricate(:post, topic: private_message, user: private_message.user)
        visible_topic = Fabricate(:topic)
        Fabricate(:post, topic: visible_topic, user: visible_topic.user)
        hidden_target_post = Fabricate(:post, topic: visible_topic, user: visible_topic.user)
        hidden_target_post.hide!(PostActionType.types[:spam])

        restricted_url = "#{Discourse.base_url}/t/#{restricted_topic.id}"
        private_message_url = "#{Discourse.base_url}/t/#{private_message.id}"
        hidden_target_url = "#{Discourse.base_url}#{hidden_target_post.url}"
        reply =
          create_post(
            user: user,
            topic: topic,
            raw: "Check out #{restricted_url}, #{private_message_url}, and #{hidden_target_url}",
          )

        expect(TopicLink.where(post: reply).pluck(:url)).to contain_exactly(
          restricted_url,
          private_message_url,
          hidden_target_url,
        )
        expect(
          TopicLink.where(
            topic: [restricted_topic, private_message],
            link_post: reply,
            reflection: true,
          ),
        ).to be_empty

        get "/composer_messages.json", params: { topic_id: topic.id, composer_action: "reply" }
        expect(response.status).to eq(200)

        duplicate_lookup = response.parsed_body["extras"]["duplicate_lookup"]
        expect(duplicate_lookup.keys).to be_empty
        expect(response.body).not_to include(restricted_topic.slug)
        expect(response.body).not_to include(private_message.slug)
      end

      it "does not include links from posts converted to whispers in duplicate_lookup" do
        SiteSetting.whispers_allowed_groups = Group::AUTO_GROUPS[:staff].to_s
        staff_user = Fabricate(:admin)
        whisper_url = "https://staff.example.com/private-doc"
        normalized_whisper_url = whisper_url.delete_prefix("https://")
        reply =
          Fabricate(
            :post,
            topic: topic,
            user: staff_user,
            raw: "Check out #{whisper_url} for details",
          )
        TopicLink.extract_from(reply)

        sign_in(staff_user)
        put "/posts/#{reply.id}/post_type.json", params: { post_type: Post.types[:whisper] }
        expect(response.status).to eq(200)

        sign_in(user)
        get "/composer_messages.json", params: { topic_id: topic.id, composer_action: "reply" }
        expect(response.status).to eq(200)

        json = response.parsed_body
        duplicate_lookup = json["extras"]["duplicate_lookup"]
        expect(duplicate_lookup).not_to have_key(normalized_whisper_url)
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
      before do
        sign_in(Fabricate(:user))
        SiteSetting.pm_warn_user_last_seen_months_ago = 24
      end

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
