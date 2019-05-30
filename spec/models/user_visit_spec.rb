# frozen_string_literal: true

require 'rails_helper'

describe UserVisit do
  fab!(:user) { Fabricate(:user) }
  fab!(:other_user) { Fabricate(:user) }

  it 'can ensure consistency' do
    user.update_visit_record!(2.weeks.ago.to_date)
    user.last_seen_at = 2.weeks.ago
    user.save
    user.update_visit_record!(1.day.ago.to_date)

    user.reload
    expect(user.user_stat.days_visited).to eq(2)

    user.user_stat.days_visited = 1
    user.save
    UserVisit.ensure_consistency!

    user.reload
    expect(user.user_stat.days_visited).to eq(2)
  end

  describe '#by_day' do
    before(:each) do
      freeze_time
      user.user_visits.create(visited_at: Time.zone.now)
      user.user_visits.create(visited_at: 1.day.ago)
      other_user.user_visits.create(visited_at: 1.day.ago)
      user.user_visits.create(visited_at: 2.days.ago)
      user.user_visits.create(visited_at: 4.days.ago)
    end
    let(:visits_by_day) { { 1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.zone.now.to_date => 1 } }

    it 'collect closed interval visits' do
      expect(UserVisit.by_day(2.days.ago, Time.zone.now)).to include(visits_by_day)
      expect(UserVisit.by_day(2.days.ago, Time.zone.now)).not_to include(4.days.ago.to_date => 1)
    end
  end
end
