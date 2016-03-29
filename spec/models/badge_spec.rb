require 'rails_helper'
require_dependency 'badge'

describe Badge do
  it { is_expected.to belong_to(:badge_type) }
  it { is_expected.to belong_to(:badge_grouping) }
  it { is_expected.to have_many(:user_badges).dependent(:destroy) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:badge_type) }
  it { is_expected.to validate_uniqueness_of(:name) }

  it 'has a valid system attribute for new badges' do
    expect(Badge.create!(name: "test", badge_type_id: 1).system?).to be false
  end

  it 'auto translates name' do
    badge = Badge.find_by_name("Basic User")
    name_english = badge.name

    I18n.locale = 'fr'

    expect(badge.display_name).not_to eq(name_english)
  end

  it 'handles changes on badge description and long description correctly for system badges' do
    badge = Badge.find_by_name("Basic User")
    badge.description = badge.description.dup
    badge.long_description = badge.long_description.dup
    badge.save
    badge.reload

    expect(badge[:description]).to eq(nil)
    expect(badge[:long_description]).to eq(nil)

    badge.description = "testing"
    badge.long_description = "testing it"

    badge.save
    badge.reload

    expect(badge[:description]).to eq("testing")
    expect(badge[:long_description]).to eq("testing it")
  end

  it 'can ensure consistency' do
    b = Badge.first
    b.grant_count = 100
    b.save

    UserBadge.create!(user_id: -100, badge_id: b.id, granted_at: 1.minute.ago, granted_by_id: -1)
    UserBadge.create!(user_id: User.first.id, badge_id: b.id, granted_at: 1.minute.ago, granted_by_id: -1)

    Badge.ensure_consistency!

    b.reload
    expect(b.grant_count).to eq(1)
  end

end

