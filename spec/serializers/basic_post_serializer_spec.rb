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

      it "returns the localized cooked" do
        SiteSetting.content_localization_enabled = true
        Fabricate(:post_localization, post: post, cooked: "X", locale: "ja")
        I18n.locale = "ja"
        post.update!(locale: "en")

        expect(json[:cooked]).to eq("X")
      end
    end
  end
end
