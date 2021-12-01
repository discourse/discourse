# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe DiscourseAutomation::UserGlobalNotice do
  fab!(:user_1) { Fabricate(:user) }

  context 'creating duplicates' do
    it 'prevents creating duplicates' do
      row = { user_id: user_1.id, notice: 'foo', identifier: 'bar', created_at: Time.now, updated_at: Time.now }

      described_class.upsert(row)

      expect {
        described_class.upsert(row)
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
