# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::ActivityCalendar do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:post_1) { Fabricate(:post, user: user, created_at: Date.new(2021, 1, 15)) }
  fab!(:post_2) { Fabricate(:post, user: user, created_at: Date.new(2021, 6, 27)) }
  fab!(:post_3) { Fabricate(:post, user: user, created_at: Date.new(2021, 6, 27)) }
  fab!(:post_4) { Fabricate(:post, user: user, created_at: Date.new(2021, 11, 27)) }
  fab!(:post_5) { Fabricate(:post, user: other_user, created_at: Date.new(2021, 11, 27)) }
  fab!(:post_6) { Fabricate(:post, user: user, created_at: Date.new(2022, 02, 27)) }

  fab!(:user_visit_1) do
    UserVisit.create!(
      user_id: user.id,
      visited_at: Date.new(2021, 3, 10),
      posts_read: 5,
      time_read: 120,
    )
  end
  fab!(:user_visit_2) do
    UserVisit.create!(
      user_id: user.id,
      visited_at: Date.new(2021, 4, 18),
      posts_read: 12,
      time_read: 1200,
    )
  end
  fab!(:user_visit_3) do
    UserVisit.create!(
      user_id: other_user.id,
      visited_at: Date.new(2021, 7, 24),
      posts_read: 12,
      time_read: 1200,
    )
  end

  it "returns an entry for all days of the last year" do
    result = call_report
    expect(result[:data].map { |d| d[:date] }.count).to eq(365)
  end

  it "counts up posts for the user on days they were made in the year" do
    result = call_report
    expect(result[:data].find { |d| d[:date] == Date.new(2021, 1, 15) }[:post_count]).to eq(1)
    expect(result[:data].find { |d| d[:date] == Date.new(2021, 6, 27) }[:post_count]).to eq(2)
    expect(result[:data].find { |d| d[:date] == Date.new(2021, 11, 27) }[:post_count]).to eq(1)
    expect(result[:data].find { |d| d[:date] == Date.new(2022, 2, 27) }).to be_nil
  end

  it "marks dates as visited for the user in the year" do
    result = call_report
    expect(result[:data].find { |d| d[:date] == Date.new(2021, 3, 10) }[:visited]).to eq(true)
    expect(result[:data].find { |d| d[:date] == Date.new(2021, 4, 18) }[:visited]).to eq(true)
    expect(result[:data].find { |d| d[:date] == Date.new(2021, 5, 1) }[:visited]).to eq(false)
  end

  context "when a post is deleted" do
    before { post_1.trash! }

    it "does not count" do
      result = call_report
      expect(result[:data].find { |d| d[:date] == Date.new(2021, 1, 15) }[:post_count]).to eq(0)
    end
  end
end
