# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::AdminDiscourseAutomationAutomationsController do
  fab!(:admin) { Fabricate(:admin) }

  before do
    sign_in(admin)
  end

  describe '#trigger' do
    fab!(:automation) { Fabricate(:automation) }

    it 'triggers the automation' do
      output = capture_stdout do
        post "/admin/plugins/discourse-automation/automations/#{automation.id}/trigger.json"
      end

      expect(output).to include('"kind":"manual"')
    end
  end

  describe '#destroy' do
    fab!(:automation) { Fabricate(:automation) }

    it 'destroys the bookmark' do
      delete "/admin/plugins/discourse-automation/automations/#{automation.id}.json"
      expect(DiscourseAutomation::Automation.find_by(id: automation.id)).to eq(nil)
    end
  end

  describe '#update' do
    fab!(:automation) { Fabricate(:automation) }

    context 'invalid field’s component' do
      it 'errors' do
        put "/admin/plugins/discourse-automation/automations/#{automation.id}.json", params: {
          automation: {
            script: automation.script,
            trigger: automation.trigger,
            fields: [
              { name: 'foo', component: 'bar' }
            ]
          }
        }

        expect(response.status).to eq(422)
      end
    end

    context 'invalid field’s metadata' do
      it 'errors' do
        put "/admin/plugins/discourse-automation/automations/#{automation.id}.json", params: {
          automation: {
            script: automation.script,
            trigger: automation.trigger,
            fields: [
              { name: 'sender', component: 'users', metadata: { baz: 1 } }
            ]
          }
        }

        expect(response.status).to eq(422)
      end
    end
  end
end
