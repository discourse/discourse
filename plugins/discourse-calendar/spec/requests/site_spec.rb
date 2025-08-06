# frozen_string_literal: true

describe "calendar site additions" do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }

  before do
    SiteSetting.calendar_enabled = true
    DiscourseCalendar.users_on_holiday = [user.username]
  end

  it "includes users_on_holiday for staff only" do
    get "/site.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["users_on_holiday"]).to eq(nil)

    sign_in(user)
    get "/site.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["users_on_holiday"]).to eq(nil)

    sign_in(admin)
    get "/site.json"
    expect(response.status).to eq(200)
    expect(response.parsed_body["users_on_holiday"]).to eq([user.username])
  end
end
