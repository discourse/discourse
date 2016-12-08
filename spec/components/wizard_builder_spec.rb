require 'rails_helper'
require 'wizard'
require 'wizard/builder'

describe Wizard::Builder do
  let(:moderator) { Fabricate.build(:moderator) }

  it "returns a wizard with steps when enabled" do
    SiteSetting.wizard_enabled = true

    wizard = Wizard::Builder.new(moderator).build
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

    wizard = Wizard::Builder.new(moderator).build
    expect(wizard).to be_present
    expect(wizard.steps).to be_blank
  end

end
