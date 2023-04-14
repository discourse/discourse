# frozen_string_literal: true

RSpec.describe PostActionType do
  describe "Callbacks" do
    describe "#expiry_cache" do
      it "should clear the cache on save" do
        cache = ApplicationSerializer.fragment_cache

        cache["post_action_types_#{I18n.locale}"] = "test"
        cache["post_action_flag_types_#{I18n.locale}"] = "test2"

        PostActionType.new(name_key: "some_key").save!

        expect(cache["post_action_types_#{I18n.locale}"]).to eq(nil)
        expect(cache["post_action_flag_types_#{I18n.locale}"]).to eq(nil)
      ensure
        ApplicationSerializer.fragment_cache.clear
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
