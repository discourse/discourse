# frozen_string_literal: true

RSpec.describe DiscourseWireframe::SaveBlockLayoutDraft do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:user)
    fab!(:theme)

    let(:dependencies) { { guardian: admin.guardian } }
    let(:layout_json) { { schema_version: 1, layout: [{ block: "hero-banner" }] }.to_json }
    let(:params) do
      {
        theme_id: theme.id,
        outlet_name: "homepage-blocks",
        layout_json: layout_json,
        base_version_token: "tok",
      }
    end

    context "when the user is not an admin" do
      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    it "upserts a private draft for the caller and writes no ThemeField" do
      expect(result).to be_a_success

      draft =
        DiscourseWireframe::BlockLayoutDraft.find_by(
          user: admin,
          theme: theme,
          outlet: "homepage-blocks",
        )
      expect(draft).to be_present
      expect(draft.data).to eq(layout_json)
      expect(draft.base_version_token).to eq("tok")
      expect(theme.theme_fields.where(type_id: ThemeField.types[:block_layout])).to be_empty
    end

    it "does not broadcast on MessageBus" do
      messages = MessageBus.track_publish { result }
      expect(
        messages.select { |message| message.channel.start_with?("/block-layouts/") },
      ).to be_empty
    end

    it "keeps one row per (user, theme, outlet), updating on a second save" do
      described_class.call(params:, **dependencies)
      updated = { schema_version: 1, layout: [{ block: "tag-cloud" }] }.to_json
      described_class.call(params: params.merge(layout_json: updated), **dependencies)

      drafts =
        DiscourseWireframe::BlockLayoutDraft.where(
          user: admin,
          theme: theme,
          outlet: "homepage-blocks",
        )
      expect(drafts.count).to eq(1)
      expect(drafts.first.data).to eq(updated)
    end

    it "accepts an invalid mid-edit layout (drafts are not baked)" do
      invalid = { schema_version: 99, layout: "not-an-array" }.to_json
      expect(described_class.call(params: params.merge(layout_json: invalid), **dependencies)).to(
        be_a_success,
      )
    end

    it "drafts a system theme (negative id), e.g. Foundation" do
      foundation = Theme.foundation_theme
      expect(foundation.id).to be < 0

      expect(
        described_class.call(params: params.merge(theme_id: foundation.id), **dependencies),
      ).to be_a_success
      expect(
        DiscourseWireframe::BlockLayoutDraft.find_by(
          user: admin,
          theme_id: foundation.id,
          outlet: "homepage-blocks",
        ),
      ).to be_present
    end

    it "rejects a theme_id of 0 (never a valid theme)" do
      expect(described_class.call(params: params.merge(theme_id: 0), **dependencies)).to(
        fail_a_contract,
      )
    end
  end
end
