# frozen_string_literal: true

require 'rails_helper'
require 'wizard'
require 'wizard/builder'
require 'global_path'

class GlobalPathInstance
  extend GlobalPath
end

describe Wizard::Builder do
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

  it "returns wizard with disabled invites step when local_logins are off" do
    SiteSetting.enable_local_logins = false

    invites_step = wizard.steps.find { |s| s.id == "invites" }
    expect(invites_step.fields).to be_blank
    expect(invites_step.disabled).to be_truthy
  end

  context 'logos step' do
    let(:logos_step) { wizard.steps.find { |s| s.id == 'logos' } }

    it 'should set the right default value for the fields' do
      upload = Fabricate(:upload)
      upload2 = Fabricate(:upload)

      SiteSetting.logo = upload
      SiteSetting.logo_small = upload2

      fields = logos_step.fields
      logo_field = fields.first
      logo_small_field = fields.last

      expect(logo_field.id).to eq('logo')
      expect(logo_field.value).to eq(GlobalPathInstance.full_cdn_url(upload.url))
      expect(logo_small_field.id).to eq('logo_small')
      expect(logo_small_field.value).to eq(GlobalPathInstance.full_cdn_url(upload2.url))
    end
  end

  context 'icons step' do
    let(:icons_step) { wizard.steps.find { |s| s.id == 'icons' } }

    it 'should set the right default value for the fields' do
      upload = Fabricate(:upload)
      upload2 = Fabricate(:upload)

      SiteSetting.favicon = upload
      SiteSetting.large_icon = upload2

      fields = icons_step.fields
      favicon_field = fields.first
      large_icon_field = fields.last

      expect(favicon_field.id).to eq('favicon')
      expect(favicon_field.value).to eq(GlobalPathInstance.full_cdn_url(upload.url))
      expect(large_icon_field.id).to eq('large_icon')
      expect(large_icon_field.value).to eq(GlobalPathInstance.full_cdn_url(upload2.url))
    end
  end

  context 'introduction step' do
    let(:wizard) { Wizard::Builder.new(moderator).build }
    let(:introduction_step) { wizard.steps.find { |s| s.id == 'introduction' } }

    context 'step has not been completed' do
      it 'enables the step' do
        expect(introduction_step.disabled).to be_nil
      end
    end

    context 'step has been completed' do
      before do
        wizard = Wizard::Builder.new(moderator).build
        introduction_step = wizard.steps.find { |s| s.id == 'introduction' }

        # manually sets the step as completed
        logger = StaffActionLogger.new(moderator)
        logger.log_wizard_step(introduction_step)
      end

      it 'disables step if no welcome topic' do
        expect(introduction_step.disabled).to eq(true)
      end

      it 'enables step if welcome topic is present' do
        topic = Fabricate(:topic, title: 'Welcome to Discourse')
        welcome_post = Fabricate(:post, topic: topic, raw: "this will be the welcome topic post\n\ncool!")

        expect(introduction_step.disabled).to be_nil
      end
    end
  end

  context 'privacy step' do
    let(:privacy_step) { wizard.steps.find { |s| s.id == 'privacy' } }

    it 'should set the right default value for the fields' do
      SiteSetting.login_required = true
      SiteSetting.invite_only = true

      fields = privacy_step.fields
      login_required_field = fields.first
      privacy_options_field = fields.last

      expect(fields.length).to eq(2)
      expect(login_required_field.id).to eq('privacy')
      expect(login_required_field.value).to eq("restricted")
      expect(privacy_options_field.id).to eq('privacy_options')
      expect(privacy_options_field.value).to eq("invite_only")
    end

    it 'should not show privacy_options field on special case' do
      SiteSetting.invite_only = true
      SiteSetting.must_approve_users = true

      fields = privacy_step.fields
      login_required_field = fields.first

      expect(fields.length).to eq(1)
      expect(login_required_field.id).to eq('privacy')
    end
  end

  context "colors step" do
    fab!(:theme) { Fabricate(:theme) }
    let(:colors_step) { wizard.steps.find { |s| s.id == 'colors' } }
    let(:field) { colors_step.fields.first }

    describe "when the default theme has not been override" do
      before do
        SiteSetting.find_by(name: "default_theme_id").destroy!
      end

      it 'should set the right default values' do
        expect(field.required).to eq(true)
        expect(field.value).to eq(ColorScheme::LIGHT_THEME_ID)
      end
    end

    describe "when the default theme has been override and the color scheme doesn't have a base scheme" do
      let(:color_scheme) { Fabricate(:color_scheme, base_scheme_id: nil) }

      before do
        SiteSetting.default_theme_id = theme.id
        theme.update(color_scheme: color_scheme)
      end

      it 'fallbacks to the color scheme name' do
        expect(field.required).to eq(false)
        expect(field.value).to eq(color_scheme.name)
      end
    end

    describe "when the default theme has been override" do
      before do
        theme.set_default!
      end

      it 'should set the right default values' do
        expect(field.required).to eq(false)
        expect(field.value).to eq(nil)
      end
    end
  end
end
