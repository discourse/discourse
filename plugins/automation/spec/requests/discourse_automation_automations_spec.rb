# frozen_string_literal: true

require 'rails_helper'
require_relative '../fabricators/automation_fabricator'

describe DiscourseAutomation::AdminDiscourseAutomationAutomationsController do
  let(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe '#destroy' do
    let!(:automation) { Fabricate(:automation) }

    it 'destroys the bookmark' do
      delete "/admin/plugins/discourse-automation/automations/#{automation.id}.json"
      expect(DiscourseAutomation::Automation.find_by(id: automation.id)).to eq(nil)
    end
  end
end
