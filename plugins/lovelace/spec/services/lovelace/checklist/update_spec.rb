# frozen_string_literal: true

RSpec.describe Lovelace::Checklist::Update do
  let(:item) do
    {
      id: "first",
      title: "Introduce yourself",
      description: "Say hello to the community.",
      link_type: "topic",
      url: "/t/welcome/123",
      button_text: "Say hello",
    }
  end

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to allow_value([], [item], [item.deep_stringify_keys]).for(:items) }
    it { is_expected.not_to allow_value(nil, "items", {}, [nil], ["item"]).for(:items) }

    it "requires each item's fields to be strings within their limits" do
      Lovelace::Checklist::FIELDS.each do |field, limit|
        expect(contract).not_to allow_value([item.except(field.to_sym)]).for(:items)
        expect(contract).not_to allow_value([item.merge(field.to_sym => 123)]).for(:items)
        expect(contract).not_to allow_value([item.merge(field.to_sym => "a" * (limit + 1))]).for(
          :items,
        )
      end
    end

    it "requires nonblank identifiers, titles, and button text" do
      %i[id title button_text].each do |field|
        expect(contract).not_to allow_value([item.merge(field => " ")]).for(:items)
      end
    end

    it "rejects duplicate identifiers and oversized checklists" do
      expect(contract).not_to allow_value([item, item.merge(title: "Another title")]).for(:items)
      expect(contract).not_to allow_value(
        Array.new(Lovelace::Checklist::MAX_ITEMS + 1) { item },
      ).for(:items)
    end

    it "rejects unsupported destinations and unsafe URLs" do
      invalid_items = [
        item.merge(link_type: "unknown"),
        item.merge(url: "/u/admin"),
        item.merge(link_type: "custom", url: "javascript:alert(1)"),
        item.merge(link_type: "custom", url: "//example.com"),
        item.merge(link_type: "custom", url: "/\\example.com"),
      ]

      invalid_items.each do |invalid_item|
        expect(contract).not_to allow_value([invalid_item]).for(:items)
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    let(:params) { { items:, revision: } }
    let(:dependencies) { { guardian: acting_user ? acting_user.guardian : Guardian.new } }
    let(:items) { [item] }
    let(:revision) { 0 }

    before { enable_current_plugin }

    context "when the plugin is disabled" do
      before { SiteSetting.lovelace_enabled = false }

      it "rejects the update without writing a configuration" do
        expect(result).to fail_a_policy(:plugin_enabled)
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to be_nil
      end
    end

    context "when the actor is anonymous" do
      fab!(:acting_user) { nil }

      it "rejects the update without writing a configuration" do
        expect(result).to fail_a_policy(:can_configure_checklist)
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to be_nil
      end
    end

    context "when the actor is an ordinary member" do
      fab!(:acting_user, :user)

      it "rejects the update without writing a configuration" do
        expect(result).to fail_a_policy(:can_configure_checklist)
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to be_nil
      end
    end

    context "when the actor is a moderator" do
      fab!(:acting_user, :moderator)

      it "rejects the update without writing a configuration" do
        expect(result).to fail_a_policy(:can_configure_checklist)
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to be_nil
      end
    end

    context "when the contract is invalid" do
      let(:items) { nil }

      it "rejects the update without writing a configuration" do
        expect(result).to fail_a_contract
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to be_nil
      end
    end

    context "when the revision is stale" do
      let(:revision) { 3 }
      let(:items) { [item, *saved_checklist["bank"]] }
      let(:saved_checklist) do
        {
          "items" => [item.deep_stringify_keys],
          "revision" => 4,
          "bank" =>
            Lovelace::Checklist.seeded_items.map do |suggestion|
              suggestion.merge("title" => "Edited #{suggestion["title"]}")
            end,
        }
      end

      before { PluginStore.set(Lovelace::PLUGIN_NAME, "checklist", saved_checklist) }

      it "preserves the current checklist and edited suggestions in its bank" do
        expect(result).to fail_a_policy(:revision_matches)
        expect(Lovelace::Checklist.read).to eq(saved_checklist)
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to eq(saved_checklist)
      end
    end

    context "when the revision is missing" do
      let(:params) { { items: } }

      it "rejects the update without writing a configuration" do
        expect(result).to fail_a_policy(:revision_matches)
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to be_nil
      end
    end

    context "when the configuration is valid" do
      let(:items) { [item.merge(title: " Welcome ", link_type: "profile", url: "")] }

      it "saves normalized items and returns the next revision" do
        expect(result).to run_successfully
        expect(result.checklist).to eq(
          "items" => [
            item.merge(
              title: "Welcome",
              link_type: "profile",
              url: "/my/preferences/profile",
            ).deep_stringify_keys,
          ],
          "revision" => 1,
          "bank" => Lovelace::Checklist.seeded_items,
        )
        expect(Lovelace::Checklist.read).to eq(result.checklist)
      end
    end

    context "when clearing an existing checklist" do
      let(:items) { [] }
      let(:revision) { "4" }

      before do
        PluginStore.set(
          Lovelace::PLUGIN_NAME,
          "checklist",
          { "items" => [item.deep_stringify_keys], "revision" => 4 },
        )
      end

      it "accepts a string revision and saves an empty checklist at the next revision" do
        expect(result).to run_successfully
        expect(result.checklist).to eq(
          "items" => [],
          "revision" => 5,
          "bank" => Lovelace::Checklist.seeded_items,
        )
        expect(Lovelace::Checklist.read).to eq(result.checklist)
      end
    end

    context "when removing an edited seeded suggestion" do
      let(:items) { [] }
      let(:revision) { 4 }
      let(:edited_suggestion) do
        Lovelace::Checklist.seeded_items.first.merge(
          "title" => "Complete your community profile",
          "description" => "Help other members recognize you.",
          "button_text" => "Edit your picture",
        )
      end

      before do
        PluginStore.set(
          Lovelace::PLUGIN_NAME,
          "checklist",
          { "items" => [edited_suggestion], "revision" => revision },
        )
      end

      it "persists its edits in the bank" do
        expect(result).to run_successfully
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to eq(
          "items" => [],
          "revision" => 5,
          "bank" => [edited_suggestion, *Lovelace::Checklist.seeded_items.drop(1)],
        )
        expect(Lovelace::Checklist.read).to eq(result.checklist)
      end
    end

    context "when restoring an edited seeded suggestion from the bank" do
      let(:items) { [edited_suggestion] }
      let(:revision) { 5 }
      let(:edited_suggestion) do
        Lovelace::Checklist.seeded_items.first.merge(
          "title" => "Complete your community profile",
          "description" => "Help other members recognize you.",
          "button_text" => "Edit your picture",
        )
      end

      before do
        PluginStore.set(
          Lovelace::PLUGIN_NAME,
          "checklist",
          {
            "items" => [],
            "revision" => revision,
            "bank" => [edited_suggestion, *Lovelace::Checklist.seeded_items.drop(1)],
          },
        )
      end

      it "keeps its edits and removes it from the bank" do
        expect(result).to run_successfully
        expect(PluginStore.get(Lovelace::PLUGIN_NAME, "checklist")).to eq(
          "items" => [edited_suggestion],
          "revision" => 6,
          "bank" => Lovelace::Checklist.seeded_items.drop(1),
        )
        expect(Lovelace::Checklist.read).to eq(result.checklist)
      end
    end
  end
end
