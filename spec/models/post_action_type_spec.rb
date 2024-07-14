# frozen_string_literal: true

RSpec.describe PostActionType do
  describe "Callbacks" do
    describe "#expiry_cache" do
      it "should clear the cache on save" do
        Discourse.redis.set("post_action_types_#{I18n.locale}", "test")
        Discourse.redis.set("post_action_flag_types_#{I18n.locale}", "test")

        PostActionType.new(name_key: "some_key").save!

        expect(Discourse.redis.get("post_action_types_#{I18n.locale}")).to eq(nil)
        expect(Discourse.redis.get("post_action_flag_types_#{I18n.locale}")).to eq(nil)
      end
    end
  end

  describe "#types" do
    context "when verifying enum sequence" do
      before { @types = PostActionType.types }

      it "'spam' should be at 8th position" do
        expect(@types[:spam]).to eq(8)
      end
    end
  end
end
