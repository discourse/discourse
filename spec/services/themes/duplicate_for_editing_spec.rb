# frozen_string_literal: true

RSpec.describe Themes::DuplicateForEditing do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:source) { Fabricate(:theme_with_remote_url, name: "Acme") }

    let(:guardian) { admin.guardian }
    let(:dependencies) { { guardian: } }
    let(:layout_json) do
      { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
    end
    let(:drafts) { [{ outlet_name: "homepage-blocks", layout_json: layout_json }] }
    let(:params) { { theme_id: source.id, drafts: drafts } }

    before do
      # A non-layout field, to prove the duplicate is a full clone (not just the
      # block layouts).
      source.set_field(target: :common, name: "scss", value: "body { color: red; }")
      source.save!
    end

    def new_theme
      Theme.find(result.theme_id)
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the theme opts out of duplication" do
      before { source.theme_modifier_set.update!(duplicable_theme: false) }

      it { is_expected.to fail_a_policy(:theme_is_duplicable) }
    end

    it "creates a new editable (non-git) theme" do
      expect { result }.to change { Theme.count }.by(1)
      expect(result).to run_successfully
      # Non-git → publishable. A directory import yields a plain local theme
      # (no remote_url), which the is_git check (remote_url presence) treats as
      # editable — exactly what the publish policy requires.
      expect(new_theme.remote_theme&.is_git?).to be_falsey
      expect(new_theme.user_selectable).to eq(false)
      expect(new_theme.name).to eq("Acme (copy)")
    end

    it "overlays the supplied drafts onto the copy" do
      field =
        new_theme.theme_fields.find_by(
          name: "homepage-blocks",
          type_id: ThemeField.types[:block_layout],
        )
      expect(field).to be_present
      expect(JSON.parse(field.value)["layout"].first["block"]).to eq("hero-banner")
    end

    it "is a full clone — non-layout fields come along" do
      scss = new_theme.theme_fields.find_by(name: "scss", type_id: ThemeField.types[:scss])
      expect(scss&.value).to eq("body { color: red; }")
    end

    it "suffixes the name on collision" do
      Fabricate(:theme, name: "Acme (copy)")
      expect(new_theme.name).to eq("Acme (copy) 2")
    end

    it "re-links the source's child components" do
      child = Fabricate(:theme, component: true)
      source.add_relative_theme!(:child, child)
      expect(new_theme.child_themes).to include(child)
    end

    context "with a component source" do
      fab!(:source) { Fabricate(:theme_with_remote_url, name: "Acme", component: true) }

      it "preserves the component flag and stays non-user-selectable" do
        expect(new_theme.component).to eq(true)
        expect(new_theme.user_selectable).to eq(false)
      end
    end

    context "with a malformed draft" do
      let(:drafts) { [{ outlet_name: "homepage-blocks", layout_json: "{not json" }] }

      it { is_expected.to fail_a_step(:validate_drafts) }

      it "does not create a theme" do
        expect { result }.not_to change { Theme.count }
      end
    end

    context "when the theme does not exist" do
      let(:params) { { theme_id: 999_999, drafts: [] } }

      it { is_expected.to fail_to_find_a_model(:theme) }
    end
  end
end
