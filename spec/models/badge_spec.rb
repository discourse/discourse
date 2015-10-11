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

end

