require 'rails_helper'
require_dependency 'wizard/step_updater'

describe Wizard::StepUpdater do
  let(:user) { Fabricate(:admin) }

  it "can update the forum title" do
    updater = Wizard::StepUpdater.new(user, 'forum_title')
    updater.update(title: 'new forum title')

    expect(updater.success?).to eq(true)
    expect(SiteSetting.title).to eq("new forum title")
  end
end
