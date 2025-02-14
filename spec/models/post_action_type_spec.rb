# frozen_string_literal: true

RSpec.describe PostActionType do
  describe "Callbacks" do
    describe "#expiry_cache" do
      it "should clear the cache on save" do
        Discourse.cache.write("post_action_types_#{I18n.locale}", "test")
        Discourse.cache.write("post_action_flag_types_#{I18n.locale}", "test2")

        PostActionType.new(name_key: "some_key").save!

        expect(Discourse.cache.read("post_action_types_#{I18n.locale}")).to eq(nil)
        expect(Discourse.cache.read("post_action_flag_types_#{I18n.locale}")).to eq(nil)
      ensure
        PostActionType.new.expire_cache
      end
    end
  end

  describe "#types" do
    context "when verifying enum sequence" do
      it "'spam' should be at 8th position" do
        expect(described_class.types[:spam]).to eq(8)
      end
    end
  end

  describe ".additional_message_types" do
    before do
      PostActionTypeView.any_instance.stubs(:overridden_by_plugin_or_skipped_db?).returns(overriden)
    end

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
