# frozen_string_literal: true

require 'rails_helper'
require_dependency 'user_badge'

describe UserBadge do

  context 'validations' do
    let(:badge) { Fabricate(:badge) }
    let(:user) { Fabricate(:user) }
    let(:subject) { BadgeGranter.grant(badge, user) }

    it { is_expected.to validate_presence_of(:badge_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:granted_at) }
    it { is_expected.to validate_presence_of(:granted_by) }
    it { is_expected.to validate_uniqueness_of(:badge_id).scoped_to(:user_id) }
  end

end
