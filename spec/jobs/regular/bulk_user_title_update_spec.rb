# frozen_string_literal: true

require 'rails_helper'

describe Jobs::BulkUserTitleUpdate do
  fab!(:badge) { Fabricate(:badge, name: 'Protector of the Realm', allow_title: true) }
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  describe 'update action' do
    before do
      BadgeGranter.grant(badge, user)
      user.update(title: badge.name)
    end

    it 'updates the title of all users with the attached granted title badge id on their profile' do
      execute_update
      expect(user.reload.title).to eq('King of the Forum')
    end

    it 'does not set the title for any other users' do
      execute_update
      expect(other_user.reload.title).not_to eq('King of the Forum')
    end

    def execute_update
      described_class.new.execute(new_title: 'King of the Forum', granted_badge_id: badge.id, action: described_class::UPDATE_ACTION)
    end
  end

  describe 'reset action' do
    let(:customized_badge_name) { 'Merit Badge' }

    before do
      TranslationOverride.upsert!(I18n.locale, Badge.i18n_key(badge.name), customized_badge_name)
      BadgeGranter.grant(badge, user)
      user.update(title: customized_badge_name)
    end

    it 'updates the title of all users back to the original badge name' do
      expect(user.reload.title).to eq(customized_badge_name)
      described_class.new.execute(granted_badge_id: badge.id, action: described_class::RESET_ACTION)
      expect(user.reload.title).to eq('Protector of the Realm')
    end

    after do
      TranslationOverride.revert!(I18n.locale, Badge.i18n_key(badge.name))
    end
  end
end
