require 'rails_helper'
require_dependency 'wizard'
require_dependency 'user'

describe WizardFieldSerializer do
  context "field id has an attached site setting" do
    DESCRIPTION = "Discourse is about discussions"

    before do
      SiteSetting.site_description = DESCRIPTION
    end

    let(:user) { Fabricate(:admin) }
    let(:wizard) {
      wizard = Wizard.new(user)
      wizard.append_step('simple') do |step|
        step.add_field(id: 'welcome', type: 'text')
      end
      wizard
    }
    let(:field) { wizard.steps.first.fields.first }
    let(:serializer) { WizardFieldSerializer.new(field, scope: Guardian.new, root: false) }
    let(:json) { serializer.as_json }

    it "uses the site setting" do
      expect(json[:value]).to eq(DESCRIPTION)
      expect(json[:overwritten_by]).to eq("site_description")
    end
  end
end
