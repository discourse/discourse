# frozen_string_literal: true

describe DiscourseReactions::CustomReactionsController do
  fab!(:user)
  fab!(:post_1) { Fabricate(:post) }

  let(:custom_emoji) { "wink" }

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_experimental_allow_any_emoji = true
    SiteSetting.discourse_reactions_enabled_reactions = "heart|thumbsup|laughing"
  end

  describe "custom emoji reactions with discourse_reactions_experimental_allow_any_emoji enabled" do
    context "when user is logged in" do
      before { sign_in(user) }

      it "allows adding custom emoji reactions when setting is enabled" do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"

        expect(response.status).to eq(200)
        json = response.parsed_body
        expect(json).to be_present
      end

      it "creates reaction with custom emoji" do
        expect do
          put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"
        end.to change { DiscourseReactions::Reaction.count }.by(1)

        reaction = DiscourseReactions::Reaction.last
        expect(reaction.reaction_value).to eq("wink")
        expect(reaction.post_id).to eq(post_1.id)
        expect(reaction.reaction_users.first.user_id).to eq(user.id)
      end

      it "allows custom emoji not in enabled_reactions list" do
        custom_emoji = "rainbow"
        expect(SiteSetting.discourse_reactions_enabled_reactions).not_to include(custom_emoji)

        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"

        expect(response.status).to eq(200)
        reaction = DiscourseReactions::Reaction.last
        expect(reaction.reaction_value).to eq(custom_emoji)
      end

      it "denys invalid emoji" do
        invalid_emoji = "a" * 20

        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{invalid_emoji}/toggle.json"

        expect(response.status).to eq(422)
      end

      it "handles emoji with skin tones" do
        custom_emoji = "wave"

        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"

        expect(response.status).to eq(200)
        reaction = DiscourseReactions::Reaction.last
        expect(reaction.reaction_value).to eq(custom_emoji)
      end

      it "can toggle custom emoji reactions on and off" do
        # Add custom emoji reaction
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"
        expect(DiscourseReactions::Reaction.count).to eq(1)

        # Remove custom emoji reaction
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"
        expect(DiscourseReactions::Reaction.count).to eq(0)
      end
    end

    context "when user is not logged in" do
      it "returns 403 forbidden" do
        put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"
        expect(response.status).to eq(403)
      end
    end
  end

  describe "custom emoji reactions with discourse_reactions_experimental_allow_any_emoji disabled" do
    before do
      SiteSetting.discourse_reactions_experimental_allow_any_emoji = false
      sign_in(user)
    end

    it "prevents adding custom emoji when setting is disabled" do
      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"

      expect(response.status).to eq(422)
      json = response.parsed_body
      expect(json["errors"]).to be_present
    end

    it "still allows reactions from enabled_reactions list" do
      enabled_reaction = "heart"
      expect(SiteSetting.discourse_reactions_enabled_reactions).to include(enabled_reaction)

      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{enabled_reaction}/toggle.json"

      expect(response.status).to eq(200)
    end
  end

  describe "validation and edge cases" do
    before { sign_in(user) }

    it "validates emoji format" do
      invalid_emoji = "invalid emoji with spaces"

      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{CGI.escape(invalid_emoji)}/toggle.json"

      expect(response.status).to eq(422)
    end

    it "handles very long emoji names" do
      long_emoji = "a" * 100

      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{long_emoji}/toggle.json"

      expect(response.status).to eq(422)
    end

    it "handles special characters in emoji names" do
      special_emoji = "+1"

      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{CGI.escape(special_emoji)}/toggle.json"

      expect(response.status).to eq(200)
      reaction = DiscourseReactions::Reaction.last
      expect(reaction.reaction_value).to eq(special_emoji)
    end

    it "prevents reactions on deleted posts" do
      post_1.trash!

      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"

      expect(response.status).to eq(404)
    end

    it "prevents reactions when reactions are disabled globally" do
      SiteSetting.discourse_reactions_enabled = false

      put "/discourse-reactions/posts/#{post_1.id}/custom-reactions/#{custom_emoji}/toggle.json"

      expect(response.status).to eq(404)
    end
  end
end
