# frozen_string_literal: true

RSpec.describe UserVisit do
  fab!(:user)
  fab!(:other_user, :user)

  it "can ensure consistency" do
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

  describe "#by_day" do
    before(:each) do
      freeze_time
      user.user_visits.create(visited_at: Time.zone.now)
      user.user_visits.create(visited_at: 1.day.ago)
      other_user.user_visits.create(visited_at: 1.day.ago)
      user.user_visits.create(visited_at: 2.days.ago)
      user.user_visits.create(visited_at: 4.days.ago)
    end
    let(:visits_by_day) do
      { 1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.zone.now.to_date => 1 }
    end

    it "collect closed interval visits" do
      expect(UserVisit.by_day(2.days.ago, Time.zone.now)).to include(visits_by_day)
      expect(UserVisit.by_day(2.days.ago, Time.zone.now)).not_to include(4.days.ago.to_date => 1)
    end
  end

  describe ".count_by_active_users" do
    fab!(:user_a, :user)
    fab!(:user_b, :user)
    fab!(:user_c, :user)

    # base day; all visits are placed relative to it so the 30-day rolling
    # window (visited_at BETWEEN day - 29 AND day) can be pinned exactly.
    let(:base) { Date.new(2026, 6, 1) }

    def visit(user, day)
      user.user_visits.create!(visited_at: day)
    end

    def mau_on(rows, day)
      rows.find { |r| r["date"] == day }&.fetch("mau")
    end

    def dau_on(rows, day)
      rows.find { |r| r["date"] == day }&.fetch("dau")
    end

    it "reports DAU and a 30-day rolling distinct MAU per active day" do
      visit(user_a, base)
      visit(user_b, base)
      visit(user_a, base + 24) # within 30 days of base -> same MAU coverage
      visit(user_c, base + 60) # far later -> its own window

      rows = UserVisit.count_by_active_users(base, base + 60)

      # base: a, b visited today and in window -> dau 2, mau 2
      expect(dau_on(rows, base)).to eq(2)
      expect(mau_on(rows, base)).to eq(2)

      # base+24: only a visited today; window [base-5, base+24] still sees a & b -> mau 2
      expect(dau_on(rows, base + 24)).to eq(1)
      expect(mau_on(rows, base + 24)).to eq(2)

      # base+60: window [base+31, base+60] sees only c -> dau 1, mau 1
      expect(dau_on(rows, base + 60)).to eq(1)
      expect(mau_on(rows, base + 60)).to eq(1)
    end

    it "treats the rolling window as 29-days-inclusive / 30-days-exclusive" do
      visit(user_a, base)
      visit(user_b, base)
      visit(user_c, base + 29) # probe day exactly 29 days after a/b
      visit(user_a, base + 30) # probe day exactly 30 days after a/b's first visit

      rows = UserVisit.count_by_active_users(base, base + 30)

      # day base+29: window [base, base+29] still includes a & b (29 inclusive) plus c
      expect(mau_on(rows, base + 29)).to eq(3)

      # day base+30: window [base+1, base+30] excludes b's only visit (base, now 30 days out);
      # a is back today, c is still in range -> a & c only
      expect(mau_on(rows, base + 30)).to eq(2)
    end

    it "counts a user once across overlapping visits and separately across a >30-day gap" do
      visit(user_a, base)
      visit(user_a, base + 10) # overlaps -> still one user in coverage
      visit(user_a, base + 100) # gap > 30 days -> new island, but still the same single user
      visit(user_b, base + 100)

      rows = UserVisit.count_by_active_users(base, base + 100)

      expect(mau_on(rows, base)).to eq(1)
      expect(mau_on(rows, base + 10)).to eq(1)
      expect(mau_on(rows, base + 100)).to eq(2)
    end

    it "only emits rows for days that had at least one visit" do
      visit(user_a, base)
      visit(user_b, base + 5)

      rows = UserVisit.count_by_active_users(base, base + 10)

      expect(rows.map { |r| r["date"] }).to contain_exactly(base, base + 5)
    end
  end
end
