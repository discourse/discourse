# frozen_string_literal: true

RSpec.describe AppearanceChange::DraftTheme do
  let(:light_colors) do
    {
      "primary" => "222222",
      "secondary" => "ffffff",
      "tertiary" => "0060df",
      "quaternary" => "e45735",
      "header_background" => "0a2540",
      "header_primary" => "ffffff",
      "highlight" => "ffff4d",
      "selected" => "d1f0ff",
      "hover" => "f2f2f2",
      "danger" => "c80001",
      "success" => "009900",
      "love" => "fa6c8d",
    }
  end
  let(:dark_colors) { ColorScheme::BUILT_IN_SCHEMES[:Dark] }

  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(name: "Acme", light_colors:, dark_colors:) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:light_colors) }
    it { is_expected.to validate_presence_of(:dark_colors) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:params) do
      { name: "Acme", light_colors:, dark_colors:, site_settings: { heading_font: "roboto" } }
    end
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when data is invalid" do
      let(:params) { { name: "Acme", light_colors: } }

      it { is_expected.to fail_a_contract }
    end

    context "when the user can't create themes" do
      fab!(:acting_user, :moderator)

      it { is_expected.to fail_a_policy(:can_create_theme) }
    end

    context "when only themes from approved repositories are allowed" do
      before do
        GlobalSetting.stubs(:allowed_theme_repos).returns("https://github.com/discourse/sample")
      end

      it { is_expected.to fail_a_policy(:local_themes_allowed) }
    end

    context "when a plugin restricts palette creation" do
      let(:plugin) { Plugin::Instance.new }
      let(:modifier) { proc { false } }

      before { plugin.register_modifier(:user_guardian_can_create_color_scheme, &modifier) }

      after do
        DiscoursePluginRegistry.unregister_modifier(
          plugin,
          :user_guardian_can_create_color_scheme,
          &modifier
        )
      end

      it { is_expected.to fail_a_policy(:can_create_color_scheme) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "saves a theme with its palettes that isn't live yet" do
        theme = result[:theme]

        expect(theme).to have_attributes(
          name: "Acme",
          component: false,
          user_selectable: false,
          default?: false,
          color_scheme: result[:light_color_scheme],
          dark_color_scheme: result[:dark_color_scheme],
        )
        expect(theme.theme_fields).to be_empty
        expect(result[:light_color_scheme].colors.to_h { [it.name, it.hex] }).to eq(light_colors)
        expect(result[:dark_color_scheme].name).to eq("Acme Dark")
      end

      it "records a draft with the fonts to apply once it is live" do
        expect(result[:appearance_change]).to have_attributes(
          kind: "theme",
          theme: result[:theme],
          user: acting_user,
          site_settings: {
            "heading_font" => "roboto",
          },
          draft?: true,
        )
      end

      it "logs the new theme" do
        expect { result }.to change {
          UserHistory.where(action: UserHistory.actions[:change_theme], acting_user:).count
        }.by(1)
      end
    end
  end
end
