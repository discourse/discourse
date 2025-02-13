# frozen_string_literal: true

RSpec.describe BasicPostSerializer do
  describe "#name" do
    let(:user) { Fabricate.build(:user) }
    let(:post) { Fabricate.build(:post, user: user, cooked: "Hur dur I am a cooked raw") }
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

      it "returns the modified cooked when register modified" do
        DiscoursePluginRegistry.register_modifier(
          Plugin::Instance.new,
          :basic_post_serializer_cooked,
        ) { "X" }

        expect(json[:cooked]).to eq("X")
      end
    end
  end
end
