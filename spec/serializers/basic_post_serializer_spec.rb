# frozen_string_literal: true

RSpec.describe BasicPostSerializer do
  describe "#name" do
    fab!(:user)
    fab!(:post) { Fabricate(:post, user: user, cooked: "Hur dur I am a cooked raw") }
    let(:serializer) { BasicPostSerializer.new(post, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "returns the name it when `enable_names` is true" do
      SiteSetting.enable_names = true
      expect(json[:name]).to be_present
    end

    it "doesn't return the name it when `enable_names` is false" do
      SiteSetting.enable_names = false
      expect(json[:name]).to be_blank
    end

    describe "#cooked" do
      it "returns the post's cooked" do
        expect(json[:cooked]).to eq(post.cooked)
      end

      describe "localizations" do
        it "returns the localized cooked" do
          SiteSetting.content_localization_enabled = true
          Fabricate(:post_localization, post: post, cooked: "X", locale: "ja")
          I18n.locale = "ja"
          post.update!(locale: "en")

          expect(json[:cooked]).to eq("X")
        end

        it "returns the site default locale cooked when no exact match found and `content_localization_use_default_locale_when_unsupported` is true" do
          SiteSetting.content_localization_enabled = true
          SiteSetting.content_localization_use_default_locale_when_unsupported = true
          SiteSetting.default_locale = "el"

          Fabricate(:post_localization, post:, cooked: "site default cooked", locale: "el")
          I18n.locale = "ja"
          post.update!(locale: "en")

          expect(json[:cooked]).to eq("site default cooked")
        end
      end
    end
  end
end
