# frozen_string_literal: true

RSpec.describe AppearanceChange::InstallTheme do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:remote_url) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:light_palette, :color_scheme)
    fab!(:dark_palette, :color_scheme)

    let(:remote_url) { "https://github.com/discourse/discourse-mint-theme" }
    let(:params) { { remote_url: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:installed_theme) do
      Fabricate(
        :theme,
        name: "Mint",
        color_scheme: light_palette,
        dark_color_scheme: dark_palette,
        remote_theme: RemoteTheme.create!(remote_url: "#{remote_url}.git"),
      ).tap do |theme|
        light_palette.update!(theme_id: theme.id)
        dark_palette.update!(theme_id: theme.id)
      end
    end

    before do
      allow(RemoteTheme).to receive(:import_theme) do |url, user, guardian:|
        expect([url, user, guardian.user]).to eq([remote_url, acting_user, acting_user])
        installed_theme
      end
    end

    context "when data is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the user can't create themes" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_create_theme) }
    end

    context "when the theme isn't on the list of popular themes" do
      let(:params) { { remote_url: "https://github.com/example/theme" } }

      it { is_expected.to fail_to_find_a_model(:popular_theme) }
    end

    context "when it's a component" do
      let(:params) { { remote_url: "https://github.com/discourse/discourse-brand-header" } }

      it { is_expected.to fail_to_find_a_model(:popular_theme) }
    end

    context "when only other theme repositories are allowed" do
      before { global_setting :allowed_theme_repos, "https://github.com/discourse/graceful" }

      it { is_expected.to fail_a_policy(:allowed_theme_repo) }
    end

    context "when the site already has the theme" do
      fab!(:existing_theme) do
        Fabricate(
          :theme,
          name: "Mint Theme",
          color_scheme: light_palette,
          remote_theme:
            RemoteTheme.create!(
              remote_url: "https://GitHub.com/discourse/discourse-mint-theme.git",
            ),
        )
      end

      it { is_expected.to run_successfully }

      it "saves it as it is, without installing it again" do
        expect(result[:appearance_change]).to have_attributes(
          kind: "existing_theme",
          name: "Mint Theme",
          theme: existing_theme,
          light_color_scheme: light_palette,
          dark_color_scheme: nil,
          activated_at: nil,
        )
        expect(RemoteTheme).not_to have_received(:import_theme)
      end

      it "reuses a change already saved for it that isn't live" do
        first = described_class.call(params:, **dependencies)[:appearance_change]

        expect { result }.not_to change { AppearanceChange.count }
        expect(result[:appearance_change]).to eq(first)
      end

      context "when the user can't create new themes" do
        before { allow_any_instance_of(Guardian).to receive(:can_create_theme?).and_return(false) }

        it { is_expected.to run_successfully }
      end

      context "when it's already the default theme" do
        before { existing_theme.set_default! }

        it { is_expected.to fail_a_policy(:not_default) }
      end

      context "when the user can't edit it" do
        before { allow_any_instance_of(Guardian).to receive(:can_edit_theme?).and_return(false) }

        it { is_expected.to fail_a_policy(:can_edit_theme) }
      end
    end

    context "when the theme can't be imported" do
      before do
        allow(RemoteTheme).to receive(:import_theme).and_raise(
          RemoteTheme::ImportError,
          "repository not found",
        )
      end

      it { is_expected.to fail_a_step(:import_theme) }

      it "saves nothing" do
        expect { result }.not_to change { AppearanceChange.count }
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves the theme without making it the default" do
        expect(result[:appearance_change]).to have_attributes(
          kind: "installed_theme",
          name: "Mint",
          theme: installed_theme,
          light_color_scheme: light_palette,
          dark_color_scheme: dark_palette,
          user: acting_user,
          activated_at: nil,
        )
        expect(installed_theme.reload).not_to be_default
      end

      it "logs the new theme" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:change_theme]).count
        }.by(1)
      end
    end
  end
end
