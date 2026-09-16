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

    def live_field(theme)
      theme.theme_fields.find_by(name: "homepage-blocks", type_id: ThemeField.types[:block_layout])
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

    it "writes the block_layout field to the theme" do
      expect(result).to be_a_success

      field = live_field(theme)
      expect(field).to be_present
      expect(JSON.parse(field.value)["layout"][0]["block"]).to eq("hero-banner")
    end

    context "with a Git-imported theme" do
      fab!(:git_theme, :theme_with_remote_url)
      let(:params) do
        { theme_id: git_theme.id, outlet_name: "homepage-blocks", layout_json: layout_json }
      end

      it { is_expected.to fail_a_policy(:theme_is_not_git) }

      it "never writes the git theme's live field" do
        described_class.call(params:, **dependencies)
        expect(live_field(git_theme)).to be_nil
      end
    end

    context "with a locally-imported theme (remote_theme with a blank URL)" do
      # An editable duplicate / customization component has a remote_theme record
      # but a blank remote_url — it is writable, unlike a real Git theme.
      fab!(:local_import, :theme)
      before { local_import.update!(remote_theme: RemoteTheme.create!(remote_url: "")) }
      let(:params) do
        { theme_id: local_import.id, outlet_name: "homepage-blocks", layout_json: layout_json }
      end

      it { is_expected.to run_successfully }

      it "writes the live field (not blocked by the git policy)" do
        described_class.call(params:, **dependencies)
        expect(live_field(local_import)).to be_present
      end
    end

    context "with the stale-publish guard" do
      it "succeeds when no expected_version_token is supplied (opt out)" do
        expect(result).to be_a_success
      end

      it "succeeds on first publish with an empty token (no live field yet)" do
        outcome =
          described_class.call(params: params.merge(expected_version_token: ""), **dependencies)
        expect(outcome).to be_a_success
      end

      it "succeeds when the expected token matches the live field" do
        described_class.call(params:, **dependencies)
        token = Themes::BlockLayoutVersion.token_for(live_field(theme).value_baked)

        outcome =
          described_class.call(params: params.merge(expected_version_token: token), **dependencies)
        expect(outcome).to be_a_success
      end

      it "fails as stale when the expected token no longer matches the live field" do
        described_class.call(params:, **dependencies)

        outcome =
          described_class.call(
            params: params.merge(expected_version_token: "stale-token"),
            **dependencies,
          )
        expect(outcome).to fail_a_step(:guard_stale_publish)
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

    it "publishes the saved layout with a version token on /block-layouts/<theme_id>" do
      messages = MessageBus.track_publish("/block-layouts/#{theme.id}") { result }

      expect(messages.length).to eq(1)
      payload = messages.first.data
      expect(payload[:outlet]).to eq("homepage-blocks")
      expect(payload[:theme_id]).to eq(theme.id)
      expect(payload[:layout][0]["block"]).to eq("hero-banner")
      expect(payload[:version_token]).to be_present
    end
  end
end
