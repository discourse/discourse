# frozen_string_literal: true

require "wizard"
require "wizard/builder"
require "global_path"

class GlobalPathInstance
  extend GlobalPath
end

RSpec.describe Wizard::Builder do
  let(:moderator) { Fabricate.build(:moderator) }
  let(:wizard) { Wizard::Builder.new(moderator).build }

  it "returns a wizard with steps when enabled" do
    SiteSetting.wizard_enabled = true

    expect(wizard).to be_present
    expect(wizard.steps).to be_present
  end

  it "returns a wizard without steps when enabled, but not staff" do
    wizard = Wizard::Builder.new(Fabricate.build(:user)).build
    expect(wizard).to be_present
    expect(wizard.steps).to be_blank
  end

  it "returns a wizard without steps when disabled" do
    SiteSetting.wizard_enabled = false

    expect(wizard).to be_present
    expect(wizard.steps).to be_blank
  end

  describe "introduction" do
    let(:introduction_step) { wizard.steps.find { |s| s.id == "introduction" } }

    it "should not prefill default site setting values" do
      fields = introduction_step.fields
      title_field = fields.first
      description_field = fields.second

      expect(title_field.id).to eq("title")
      expect(title_field.value).to eq("")
      expect(description_field.id).to eq("site_description")
      expect(description_field.value).to eq("")
    end

    it "should prefill overridden site setting values" do
      SiteSetting.title = "foobar"
      SiteSetting.site_description = "lorem ipsum"
      SiteSetting.contact_email = "foobar@example.com"

      fields = introduction_step.fields
      title_field = fields.first
      description_field = fields.second

      expect(title_field.id).to eq("title")
      expect(title_field.value).to eq("foobar")
      expect(description_field.id).to eq("site_description")
      expect(description_field.value).to eq("lorem ipsum")
    end
  end

  describe "privacy step" do
    let(:privacy_step) { wizard.steps.find { |s| s.id == "privacy" } }

    it "should set the right default value for the fields" do
      SiteSetting.login_required = true
      SiteSetting.invite_only = false
      SiteSetting.must_approve_users = true
      SiteSetting.chat_enabled = true if defined?(::Chat)
      SiteSetting.navigation_menu = NavigationMenuSiteSetting::SIDEBAR

      fields = privacy_step.fields
      login_required_field = fields.first
      invite_only_field = fields.second
      must_approve_users_field = fields.third
      chat_enabled_field = fields.second_to_last if defined?(::Chat)
      navigation_menu_field = fields.last

      count = defined?(::Chat) ? 4 : 3
      expect(fields.length).to eq(count)
      expect(login_required_field.id).to eq("login_required")
      expect(login_required_field.value).to eq("private")
      expect(invite_only_field.id).to eq("invite_only")
      expect(invite_only_field.value).to eq("sign_up")
      expect(must_approve_users_field.id).to eq("must_approve_users")
      expect(must_approve_users_field.value).to eq("yes")
    end
  end

  describe "styling" do
    let(:styling_step) { wizard.steps.find { |s| s.id == "styling" } }
    let(:font_field) { styling_step.fields.find { |f| f.id == "body_font" } }
    fab!(:theme)
    let(:colors_field) { styling_step.fields.first }

    it "has the full list of available fonts in alphabetical order" do
      expect(font_field.choices.map(&:label)).to eq(DiscourseFonts.fonts.map { |f| f[:name] }.sort)
    end

    context "with colors" do
      context "when the default theme has not been override" do
        before { SiteSetting.find_by(name: "default_theme_id").destroy! }

        it "should set the right default values" do
          expect(colors_field.required).to eq(true)
          expect(colors_field.value).to eq(ColorScheme::LIGHT_THEME_ID)
        end
      end

      context "when the default theme has been override and the color scheme doesn't have a base scheme" do
        let(:color_scheme) { Fabricate(:color_scheme, base_scheme_id: nil) }

        before do
          SiteSetting.default_theme_id = theme.id
          theme.update(color_scheme: color_scheme)
        end

        it "fallbacks to the color scheme name" do
          expect(colors_field.required).to eq(false)
          expect(colors_field.value).to eq(color_scheme.name)
        end
      end

      context "when the default theme has been overridden by a theme without a color scheme" do
        before { theme.set_default! }

        it "should set the right default values" do
          expect(colors_field.required).to eq(false)
          expect(colors_field.value).to eq("Light")
        end
      end

      context "when the default theme has been overridden by a theme with a color scheme" do
        before do
          theme.update(color_scheme_id: ColorScheme.find_by_name("Dark").id)
          theme.set_default!
        end

        it "should set the right default values" do
          expect(colors_field.required).to eq(false)
          expect(colors_field.value).to eq("Dark")
        end
      end
    end
  end

  describe "branding" do
    let(:branding_step) { wizard.steps.find { |s| s.id == "branding" } }

    it "should set the right default value for the fields" do
      upload = Fabricate(:upload)
      upload2 = Fabricate(:upload)

      SiteSetting.logo = upload
      SiteSetting.logo_small = upload2

      fields = branding_step.fields
      logo_field = fields.first
      logo_small_field = fields.last

      expect(logo_field.id).to eq("logo")
      expect(logo_field.value).to eq(GlobalPathInstance.full_cdn_url(upload.url))
      expect(logo_small_field.id).to eq("logo_small")
      expect(logo_small_field.value).to eq(GlobalPathInstance.full_cdn_url(upload2.url))
    end
  end
end
