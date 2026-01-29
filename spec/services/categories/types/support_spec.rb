# frozen_string_literal: true

RSpec.describe Categories::Types::Support do
  describe ".available?" do
    context "when discourse-solved is not loaded" do
      before { allow(described_class).to receive(:available?).and_call_original }

      it "returns false when DiscourseSolved is not defined" do
        hide_const("DiscourseSolved") if defined?(DiscourseSolved)
        expect(described_class.available?).to be_falsey
      end
    end

    context "when discourse-solved is loaded", if: defined?(DiscourseSolved) do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  describe ".type_id" do
    it "returns :support" do
      expect(described_class.type_id).to eq(:support)
    end
  end

  describe ".icon" do
    it "returns square-check" do
      expect(described_class.icon).to eq("square-check")
    end
  end

  describe ".enable_plugin", if: defined?(DiscourseSolved) do
    it "enables the solved_enabled setting" do
      SiteSetting.solved_enabled = false

      described_class.enable_plugin

      expect(SiteSetting.solved_enabled).to be true
    end
  end

  describe ".configure_category", if: defined?(DiscourseSolved) do
    fab!(:category)

    it "sets the enable_accepted_answers custom field" do
      described_class.configure_category(category)

      category.reload
      expect(category.custom_fields[DiscourseSolved::ENABLE_ACCEPTED_ANSWERS_CUSTOM_FIELD]).to eq(
        "true",
      )
    end
  end
end
