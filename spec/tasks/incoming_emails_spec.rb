# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "incoming emails tasks" do
  before do
    Discourse::Application.load_tasks
  end

  describe 'email with attachment' do
    fab!(:incoming_email) { Fabricate(:incoming_email, raw: email(:attached_txt_file)) }

    it 'updates record' do
      expect { Rake::Task['incoming_emails:truncate_long'].invoke }.to change { incoming_email.reload.updated_at }
    end
  end

  describe 'short email without attachment' do
    fab!(:incoming_email) { Fabricate(:incoming_email, raw: email(:html_reply)) }
    it 'does not update record' do
      expect { Rake::Task['incoming_emails:truncate_long'].invoke }.not_to change { incoming_email.reload.updated_at }
    end
  end
end
