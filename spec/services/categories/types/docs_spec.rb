# frozen_string_literal: true

RSpec.describe Categories::Types::Docs do
  describe ".available?" do
    context "when discourse-docs is not loaded" do
      before { allow(described_class).to receive(:available?).and_call_original }

      it "returns false when DiscourseDocs is not defined" do
        hide_const("DiscourseDocs") if defined?(DiscourseDocs)
        expect(described_class.available?).to be_falsey
      end
    end

    context "when discourse-docs is loaded", if: defined?(DiscourseDocs) do
      it "returns true" do
        expect(described_class.available?).to be true
      end
    end
  end

  describe ".type_id" do
    it "returns :docs" do
      expect(described_class.type_id).to eq(:docs)
    end
  end

  describe ".icon" do
    it "returns book" do
      expect(described_class.icon).to eq("book")
    end
  end

  describe ".enable_plugin", if: defined?(DiscourseDocs) do
    it "enables the docs_enabled setting" do
      SiteSetting.docs_enabled = false

      described_class.enable_plugin

      expect(SiteSetting.docs_enabled).to be true
    end
  end

  describe ".configure_site_settings", if: defined?(DiscourseDocs) do
    fab!(:category)

    it "adds category to docs_categories" do
      SiteSetting.docs_categories = ""

      described_class.configure_site_settings(category)

      expect(SiteSetting.docs_categories).to eq(category.id.to_s)
    end

    it "appends to existing categories list" do
      SiteSetting.docs_categories = "999"

      described_class.configure_site_settings(category)

      expect(SiteSetting.docs_categories).to eq("999|#{category.id}")
    end

    it "does not duplicate category in list" do
      SiteSetting.docs_categories = category.id.to_s

      described_class.configure_site_settings(category)

      expect(SiteSetting.docs_categories).to eq(category.id.to_s)
    end
  end

  describe ".configure_category" do
    fab!(:category)

    it "does nothing" do
      expect { described_class.configure_category(category) }.not_to raise_error
    end
  end
end
