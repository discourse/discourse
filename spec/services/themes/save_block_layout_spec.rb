# frozen_string_literal: true

RSpec.describe Themes::SaveBlockLayout do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:theme_id) }
    it { is_expected.to validate_presence_of(:outlet_name) }
    it { is_expected.to validate_presence_of(:layout_json) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:theme)

    let(:guardian) { admin.guardian }
    let(:dependencies) { { guardian: } }
    let(:layout_json) do
      { schema_version: 1, layout: [{ block: "hero-banner", args: { title: "Hi" } }] }.to_json
    end
    let(:params) do
      { theme_id: theme.id, outlet_name: "homepage-blocks", layout_json: layout_json }
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the theme does not exist" do
      let(:params) do
        { theme_id: 999_999_999, outlet_name: "homepage-blocks", layout_json: layout_json }
      end

      it { is_expected.to fail_to_find_a_model(:theme) }
    end

    context "with invalid params" do
      it "fails when the outlet name is missing" do
        result = described_class.call(params: params.merge(outlet_name: ""), **dependencies)
        expect(result).to fail_a_contract
      end

      it "fails when the outlet name has illegal characters" do
        result =
          described_class.call(params: params.merge(outlet_name: "Invalid Name!"), **dependencies)
        expect(result).to fail_a_contract
      end
    end

    context "with a non-Git theme (no remote_theme_id)" do
      it "writes the field directly to the parent theme" do
        expect(result).to be_a_success
        expect(result.target_theme).to eq(theme)
        expect(result.redirected).to eq(false)
        expect(result.child_created).to eq(false)

        field =
          theme.theme_fields.find_by(
            name: "homepage-blocks",
            type_id: ThemeField.types[:block_layout],
          )
        expect(field).to be_present
        expect(JSON.parse(field.value)["layout"][0]["block"]).to eq("hero-banner")
      end
    end

    context "with a Git-imported theme" do
      fab!(:git_theme, :theme_with_remote_url)
      let(:params) do
        { theme_id: git_theme.id, outlet_name: "homepage-blocks", layout_json: layout_json }
      end

      it "auto-creates a -customizations child component on first save" do
        expect(result).to be_a_success
        expect(result.target_theme).not_to eq(git_theme)
        expect(result.target_theme.name).to eq("#{git_theme.name}-customizations")
        expect(result.target_theme.component?).to eq(true)
        expect(result.target_theme.remote_theme_id).to be_nil
        expect(result.redirected).to eq(true)
        expect(result.child_created).to eq(true)
        expect(git_theme.reload.child_theme_ids).to include(result.target_theme.id)
      end

      it "reuses an existing -customizations child on subsequent saves" do
        described_class.call(params:, **dependencies)
        before_count = Theme.where(name: "#{git_theme.name}-customizations").count

        result = described_class.call(params:, **dependencies)
        expect(result).to be_a_success
        expect(result.child_created).to eq(false)
        expect(Theme.where(name: "#{git_theme.name}-customizations").count).to eq(before_count)
      end

      it "writes directly to the parent theme when force_parent is true" do
        forced = described_class.call(params: params.merge(force_parent: true), **dependencies)
        expect(forced).to be_a_success
        expect(forced.target_theme).to eq(git_theme)
        expect(forced.redirected).to eq(false)
      end
    end

    context "when the layout JSON is structurally invalid" do
      let(:params) do
        {
          theme_id: theme.id,
          outlet_name: "homepage-blocks",
          layout_json: { schema_version: 99, layout: [] }.to_json,
        }
      end

      it "fails the bake-error guard step" do
        expect(result).to be_a_failure
        expect(result["result.step.guard_against_bake_error"].error).to match(
          /Unsupported block_layout schema_version/,
        )
      end
    end

    context "with the MessageBus broadcast" do
      it "publishes the saved layout on /block-layouts/<theme_id>" do
        messages = MessageBus.track_publish("/block-layouts/#{theme.id}") { result }

        expect(messages.length).to eq(1)
        payload = messages.first.data
        expect(payload[:outlet]).to eq("homepage-blocks")
        expect(payload[:theme_id]).to eq(theme.id)
        expect(payload[:layout][0]["block"]).to eq("hero-banner")
      end

      it "publishes against the redirected target theme for Git-imported saves" do
        git_theme = Fabricate(:theme_with_remote_url)
        git_params = {
          theme_id: git_theme.id,
          outlet_name: "homepage-blocks",
          layout_json: layout_json,
        }

        messages =
          MessageBus.track_publish { described_class.call(params: git_params, **dependencies) }
        block_layout_messages = messages.select { |m| m.channel.start_with?("/block-layouts/") }

        expect(block_layout_messages.length).to eq(1)
        # The save is redirected to the auto-created child component, so the
        # channel should NOT be the parent (Git-imported) theme's id.
        expect(block_layout_messages.first.channel).not_to eq("/block-layouts/#{git_theme.id}")
        # And the data's theme_id should match the channel id.
        channel_id = block_layout_messages.first.channel[%r{\A/block-layouts/(\d+)\z}, 1].to_i
        expect(block_layout_messages.first.data[:theme_id]).to eq(channel_id)
      end
    end
  end
end
