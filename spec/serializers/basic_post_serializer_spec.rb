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
        plugin = Plugin::Instance.new
        modifier = :basic_post_serializer_cooked
        proc = Proc.new { "X" }
        DiscoursePluginRegistry.register_modifier(plugin, modifier, &proc)

        expect(json[:cooked]).to eq("X")
      ensure
        DiscoursePluginRegistry.unregister_modifier(plugin, modifier, &proc)
      end
    end
  end
end
