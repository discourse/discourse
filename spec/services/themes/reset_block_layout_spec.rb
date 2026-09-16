# frozen_string_literal: true

RSpec.describe Themes::ResetBlockLayout do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:theme)

    let(:dependencies) { { guardian: admin.guardian } }
    let(:params) { { theme_id: theme.id, outlet_name: "homepage-blocks" } }
    let(:layout_json) { { schema_version: 1, layout: [{ block: "hero-banner" }] }.to_json }

    def live_field
      theme.theme_fields.find_by(name: "homepage-blocks", type_id: ThemeField.types[:block_layout])
    end

    def set_live_field
      theme.set_field(
        target: :common,
        name: "homepage-blocks",
        type: :block_layout,
        value: layout_json,
      )
      theme.save!
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "with a Git-imported theme" do
      fab!(:git_theme, :theme_with_remote_url)
      let(:params) { { theme_id: git_theme.id, outlet_name: "homepage-blocks" } }

      it { is_expected.to fail_a_policy(:theme_is_not_git) }
    end

    context "with a locally-imported theme (remote_theme with a blank URL)" do
      fab!(:local_import, :theme)
      before { local_import.update!(remote_theme: RemoteTheme.create!(remote_url: "")) }
      let(:params) { { theme_id: local_import.id, outlet_name: "homepage-blocks" } }

      # Writable, unlike a real Git theme — the policy must not block it.
      it { is_expected.not_to fail_a_policy(:theme_is_not_git) }
    end

    it "deletes the live field" do
      set_live_field

      expect(result).to be_a_success
      expect(live_field).to be_nil
    end

    it "broadcasts the removal with a nil layout" do
      set_live_field

      messages = MessageBus.track_publish("/block-layouts/#{theme.id}") { result }
      expect(messages.length).to eq(1)
      payload = messages.first.data
      expect(payload[:outlet]).to eq("homepage-blocks")
      expect(payload[:layout]).to be_nil
    end
  end
end
