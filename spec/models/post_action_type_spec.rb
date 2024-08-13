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

  describe ".additional_message_types" do
    before { described_class.stubs(:overridden_by_plugin_or_skipped_db?).returns(overriden) }

    context "when overridden by plugin or skipped DB" do
      let(:overriden) { true }

      it "returns additional types from flag settings" do
        expect(described_class.additional_message_types).to eq(
          described_class.flag_settings.additional_message_types,
        )
      end
    end

    context "when not overriden by plugin or skipped DB" do
      let(:overriden) { false }

      it "returns all flags" do
        expect(described_class.additional_message_types).to eq(
          illegal: 10,
          notify_moderators: 7,
          notify_user: 6,
        )
      end
    end
  end
end
