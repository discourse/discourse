# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::ReadingTime do
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:user_visit_1) do
    Fabricate(
      :user_visit,
      user: user,
      visited_at: Date.new(2021, 3, 10),
      posts_read: 5,
      time_read: 100,
    )
  end
  fab!(:user_visit_2) do
    Fabricate(
      :user_visit,
      user: user,
      visited_at: Date.new(2021, 4, 18),
      posts_read: 12,
      time_read: 1000,
    )
  end
  fab!(:user_visit_3) do
    Fabricate(
      :user_visit,
      user: other_user,
      visited_at: Date.new(2021, 7, 24),
      posts_read: 8,
      time_read: 1200,
    )
  end

  it "calculates reading time for the year correctly" do
    result = call_report
    expect(result[:data][:reading_time]).to eq(1100)
  end

  def read_for(seconds)
    user_visit_1.update!(time_read: seconds - user_visit_2.time_read)
    call_report
  end

  it "picks the shortest book that takes longer than the reading time" do
    expect(read_for(3119)[:data][:book]).to eq("The Metamorphosis")
    expect(read_for(3120)[:data][:book]).to eq("The Little Prince")
  end

  it "flags series" do
    expect(read_for(359_900)[:data]).to include(book: "The Game of Thrones Series", series: true)
  end

  it "returns nothing when the reading time exceeds every book" do
    longest = described_class::POPULAR_BOOKS.values.pluck(:reading_time).max

    expect(read_for(longest)).to be_nil
  end
end
