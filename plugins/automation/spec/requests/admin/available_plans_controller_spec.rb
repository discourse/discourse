# frozen_string_literal: true

require 'rails_helper'

describe DiscourseAutomation::AvailablePlansController do

  context 'as staff' do
    fab!(:staff) { Fabricate(:moderator) }

    before do
      DiscourseAutomation.reset!
      sign_in(staff)
    end

    context 'index' do
      before do
        DiscourseAutomation::Plannable.add(:foo)
        DiscourseAutomation::Plannable.add(:bar)
      end

      it 'lists available plans' do
        get '/admin/plugins/discourse-automation/plannables.json'

        expect(response.status).to eq(200)

        result = JSON.parse(response.body)
        expect(result.length).to eq(2)
        expect(result[0]['key']).to eq('foo')
        expect(result[0]['type']).to eq(DiscourseAutomation::Plan.types[:custom])
      end
    end
  end

  context 'as a user' do
    fab!(:user) { Fabricate(:user) }

    before { sign_in(user) }

    it 'prevents access' do
      get '/admin/plugins/discourse-automation/plannables.json'

      expect(response.status).to eq(403)
    end
  end

  context 'as not logged in' do
    context 'index' do
      it 'prevents access' do
        get '/admin/plugins/discourse-automation/plannables.json'

        expect(response.status).to eq(403)
      end
    end
  end
end
