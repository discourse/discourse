require 'rails_helper'

describe SiteSettingsTask do

  before do
    Discourse::Application.load_tasks
  end

  describe 'export' do
    it 'creates a hash of all site settings' do
      h = SiteSettingsTask.export_to_hash
      expect(h.count).to be > 0
    end
  end

  describe 'import' do
    it 'updates site settings' do
      yml = "title: Test"
      log, counts = SiteSettingsTask.import(yml)
      expect(log[0]).to eq "Changed title FROM: Discourse TO: Test"
      expect(counts[:updated]).to eq 1
      expect(SiteSetting.title).to eq "Test"
    end
  end
end
