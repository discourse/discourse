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

  it "returns wizard with disabled invites step when local_logins are off" do
    SiteSetting.enable_local_logins = false

    wizard = Wizard::Builder.new(moderator).build

    invites_step = wizard.steps.find { |s| s.id == "invites" }
    expect(invites_step.fields).to be_blank
    expect(invites_step.disabled).to be_truthy
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
end
