# frozen_string_literal: true

RSpec.describe DiscourseRewind::Action::ReadingTime do
  fab!(:date) { Date.new(2021).all_year }
  fab!(:user)
  fab!(:other_user, :user)

  fab!(:user_visit_1) do
    UserVisit.create!(
      user_id: user.id,
      visited_at: Date.new(2021, 3, 10),
      posts_read: 5,
      time_read: 100,
    )
  end
  fab!(:user_visit_2) do
    UserVisit.create!(
      user_id: user.id,
      visited_at: Date.new(2021, 4, 18),
      posts_read: 12,
      time_read: 1000,
    )
  end
  fab!(:user_visit_3) do
    UserVisit.create!(
      user_id: other_user.id,
      visited_at: Date.new(2021, 7, 24),
      posts_read: 8,
      time_read: 1200,
    )
  end

  def new_target_time_read(value)
    value - 1000
  end

  it "calculates reading time for the year correctly" do
    result = call_report
    expect(result[:data][:reading_time]).to eq(1100)
  end

  it "matches the correct book based on reading time" do
    result = call_report
    expect(result[:data][:book]).to eq("The Metamorphosis")

    user_visit_1.update!(time_read: new_target_time_read(5300))
    result = call_report
    expect(result[:data][:book]).to eq("The Little Prince")

    user_visit_1.update!(time_read: new_target_time_read(7100))
    result = call_report
    expect(result[:data][:book]).to eq("Animal Farm")

    user_visit_1.update!(time_read: new_target_time_read(10_700))
    result = call_report
    expect(result[:data][:book]).to eq("The Alchemist")

    user_visit_1.update!(time_read: new_target_time_read(12_500))
    result = call_report
    expect(result[:data][:book]).to eq("The Great Gatsby")

    user_visit_1.update!(time_read: new_target_time_read(14_900))
    result = call_report
    expect(result[:data][:book]).to eq("Fahrenheit 451")

    user_visit_1.update!(time_read: new_target_time_read(16_100))
    result = call_report
    expect(result[:data][:book]).to eq("And Then There Were None")

    user_visit_1.update!(time_read: new_target_time_read(16_700))
    result = call_report
    expect(result[:data][:book]).to eq("1984")

    user_visit_1.update!(time_read: new_target_time_read(17_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Catcher in the Rye")

    user_visit_1.update!(time_read: new_target_time_read(19_640))
    result = call_report
    expect(result[:data][:book]).to eq("The Hunger Games")

    user_visit_1.update!(time_read: new_target_time_read(22_700))
    result = call_report
    expect(result[:data][:book]).to eq("To Kill a Mockingbird")

    user_visit_1.update!(time_read: new_target_time_read(24_500))
    result = call_report
    expect(result[:data][:book]).to eq("A Tale of Two Cities")

    user_visit_1.update!(time_read: new_target_time_read(25_100))
    result = call_report
    expect(result[:data][:book]).to eq("Pride and Prejudice")

    user_visit_1.update!(time_read: new_target_time_read(26_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Hobbit")

    user_visit_1.update!(time_read: new_target_time_read(29_900))
    result = call_report
    expect(result[:data][:book]).to eq("Little Women")

    user_visit_1.update!(time_read: new_target_time_read(34_100))
    result = call_report
    expect(result[:data][:book]).to eq("Jane Eyre")

    user_visit_1.update!(time_read: new_target_time_read(37_700))
    result = call_report
    expect(result[:data][:book]).to eq("The Da Vinci Code")

    user_visit_1.update!(time_read: new_target_time_read(46_700))
    result = call_report
    expect(result[:data][:book]).to eq("One Hundred Years of Solitude")

    user_visit_1.update!(time_read: new_target_time_read(107_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Lord of the Rings")

    user_visit_1.update!(time_read: new_target_time_read(179_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Complete works of Shakespeare")

    user_visit_1.update!(time_read: new_target_time_read(359_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Game of Thrones Series")

    user_visit_1.update!(time_read: new_target_time_read(719_900))
    result = call_report
    expect(result[:data][:book]).to eq("Malazan Book of the Fallen")

    user_visit_1.update!(time_read: new_target_time_read(1_439_900))
    result = call_report
    expect(result[:data][:book]).to eq("Terry Pratchett's Discworld series")

    user_visit_1.update!(time_read: new_target_time_read(2_159_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Wandering Inn web series")

    user_visit_1.update!(time_read: new_target_time_read(2_879_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Combined Cosmere works + Wheel of Time")

    user_visit_1.update!(time_read: new_target_time_read(3_599_900))
    result = call_report
    expect(result[:data][:book]).to eq("The Star Trek novels")
  end
end
