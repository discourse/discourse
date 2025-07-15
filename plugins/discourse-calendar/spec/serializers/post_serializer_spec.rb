# frozen_string_literal: true

require "rails_helper"

describe PostSerializer do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  it "includes calendar events" do
    calendar_post = create_post(raw: "[calendar]\n[/calendar]")

    freeze_time Date.new(2018, 5, 1)
    post = create_post(topic: calendar_post.topic, raw: 'Rome [date="2018-06-05" time="10:20:00"]')

    json = PostSerializer.new(calendar_post, scope: Guardian.new).as_json
    expect(json[:post][:calendar_details].size).to eq(1)
  end

  it "includes group timezones" do
    Fabricate(:admin, refresh_auto_groups: true)

    calendar_post =
      create_post(
        raw:
          "[timezones group=\"admins\"]\n[/timezones]\n\n[timezones group=\"trust_level_0\"]\n[/timezones]",
      )

    json = PostSerializer.new(calendar_post.reload, scope: Guardian.new).as_json
    expect(json[:post][:group_timezones]["admins"].count).to eq(1)
    expect(json[:post][:group_timezones]["trust_level_0"].count).to eq(2)
  end

  it "groups calendar events correctly" do
    user = Fabricate(:user)
    user.upsert_custom_fields(::DiscourseCalendar::REGION_CUSTOM_FIELD => "ar")
    user.user_option.update!(timezone: "America/Buenos_Aires")

    user2 = Fabricate(:user)
    user2.upsert_custom_fields(::DiscourseCalendar::REGION_CUSTOM_FIELD => "ar")
    user2.user_option.update!(timezone: "America/Buenos_Aires")

    post = create_post(raw: "[calendar]\n[/calendar]")
    SiteSetting.holiday_calendar_topic_id = post.topic.id

    freeze_time Date.new(2021, 4, 1)
    ::DiscourseCalendar::CreateHolidayEvents.new.execute({})

    json = PostSerializer.new(post.reload, scope: Guardian.new).as_json
    expect(
      json[:post][:calendar_details].map { |x| { x[:from].year => x[:name] } },
    ).to contain_exactly(
      { 2021 => "Día del Veterano y de los Caídos en la Guerra de Malvinas, Viernes Santo" },
      { 2021 => "Día de la Revolución de Mayo" },
      { 2021 => "Feriado puente turístico" },
      { 2021 => "Día de la Independencia" },
      { 2021 => "Paso a la Inmortalidad del General José de San Martín" },
    )
    expect(json[:post][:calendar_details].map { |x| x[:users] }).to all(
      contain_exactly(
        { username: user.username, timezone: "America/Buenos_Aires" },
        { username: user2.username, timezone: "America/Buenos_Aires" },
      ),
    )

    freeze_time Date.new(2022, 4, 1)
    ::DiscourseCalendar::CreateHolidayEvents.new.execute({})

    json = PostSerializer.new(post.reload, scope: Guardian.new).as_json
    expect(json[:post][:calendar_details].map { |x| { x[:from].year => x[:name] } }).to include(
      { 2022 => "Viernes Santo" },
      { 2022 => "Día de la Revolución de Mayo" },
      { 2022 => "Día de la Bandera" },
      { 2022 => "Feriado puente turístico" },
      { 2022 => "Paso a la Inmortalidad del General José de San Martín" },
    )
  end
end
