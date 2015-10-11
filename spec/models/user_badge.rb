require 'rails_helper'
require_dependency 'user_badge'

describe UserBadge do

  context 'validations' do
    before(:each) { BadgeGranter.grant(Fabricate(:badge), Fabricate(:user)) }

    it { is_expected.to validate_presence_of(:badge_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:granted_at) }
    it { is_expected.to validate_presence_of(:granted_by) }
    it { is_expected.to validate_uniqueness_of(:badge_id).scoped_to(:user_id) }
  end

end
