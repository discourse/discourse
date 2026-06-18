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

  describe "setup step" do
    let(:setup_step) { wizard.steps.find { |s| s.id == "setup" } }

    it "should not prefill default site setting values" do
      fields = setup_step.fields
      title_field = fields.first

      expect(title_field.id).to eq("title")
      expect(title_field.value).to eq("")
    end

    it "should prefill overridden site setting values" do
      SiteSetting.title = "foobar"

      fields = setup_step.fields
      title_field = fields.first

      expect(title_field.id).to eq("title")
      expect(title_field.value).to eq("foobar")
    end

    it "should set the right default value for privacy fields" do
      SiteSetting.login_required = true
      SiteSetting.invite_only = false
      SiteSetting.must_approve_users = true

      fields = setup_step.fields
      login_required_field = fields[2]
      invite_only_field = fields[3]
      must_approve_users_field = fields[4]

      expect(login_required_field.id).to eq("login_required")
      expect(login_required_field.value).to eq("private")
      expect(invite_only_field.id).to eq("invite_only")
      expect(invite_only_field.value).to eq("sign_up")
      expect(must_approve_users_field.id).to eq("must_approve_users")
      expect(must_approve_users_field.value).to eq("yes")
    end
  end
end
