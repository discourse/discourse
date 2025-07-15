# frozen_string_literal: true

describe DiscourseCalendar::CreateHolidayEvents do
  let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

  let(:frenchy) do
    Fabricate(:user, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" })
  end
  let(:aussie) do
    Fabricate(:user, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "au" })
  end

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.holiday_calendar_topic_id = calendar_post.topic_id
  end

  it "can be disabled" do
    SiteSetting.calendar_automatic_holidays_enabled = false

    frenchy
    freeze_time Time.zone.local(2019, 8, 1)
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    expect(CalendarEvent.where(user_id: frenchy.id).count).to eq(0)
  end

  it "adds all holidays in the next 6 months" do
    frenchy
    freeze_time Time.zone.local(2019, 8, 1)
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    expect(CalendarEvent.pluck(:region, :description, :start_date, :user_id)).to match_array(
      [
        ["fr", "Assomption", Date.parse("2019-08-15"), frenchy.id],
        ["fr", "Toussaint", Date.parse("2019-11-01"), frenchy.id],
        ["fr", "Armistice 1918", Date.parse("2019-11-11"), frenchy.id],
        ["fr", "Noël", Date.parse("2019-12-25"), frenchy.id],
        ["fr", "Jour de l'an", Date.parse("2020-01-01"), frenchy.id],
      ],
    )
  end

  it "checks for observed dates" do
    aussie
    freeze_time Time.zone.local(2020, 1, 20)
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    # The "Australia Day" is always observed on a Monday
    expect(CalendarEvent.pluck(:region, :description, :start_date, :user_id)).to match_array(
      [
        ["au", "Australia Day", Date.parse("2020-01-27"), aussie.id],
        ["au", "Good Friday", Date.parse("2020-04-10"), aussie.id],
        ["au", "Easter Monday", Date.parse("2020-04-13"), aussie.id],
      ],
    )
  end

  it "only checks for holidays during business days" do
    frenchy
    freeze_time Time.zone.local(2019, 7, 1)
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    # The "Fête Nationale" is on July 14th but it's on a Sunday in 2019
    expect(CalendarEvent.pluck(:region, :description, :start_date, :user_id)).to match_array(
      [
        ["fr", "Assomption", Date.parse("2019-08-15"), frenchy.id],
        ["fr", "Toussaint", Date.parse("2019-11-01"), frenchy.id],
        ["fr", "Armistice 1918", Date.parse("2019-11-11"), frenchy.id],
        ["fr", "Noël", Date.parse("2019-12-25"), frenchy.id],
        ["fr", "Jour de l'an", Date.parse("2020-01-01"), frenchy.id],
      ],
    )
  end

  it "only takes into account active users" do
    freeze_time Time.zone.local(2019, 8, 1)

    robot =
      Fabricate(:user, id: -100, custom_fields: { DiscourseCalendar::REGION_CUSTOM_FIELD => "fr" })
    inactive =
      Fabricate(
        :user,
        active: false,
        custom_fields: {
          DiscourseCalendar::REGION_CUSTOM_FIELD => "fr",
        },
      )
    suspended =
      Fabricate(
        :user,
        suspended_till: 1.year.from_now,
        custom_fields: {
          DiscourseCalendar::REGION_CUSTOM_FIELD => "fr",
        },
      )
    silenced =
      Fabricate(
        :user,
        silenced_till: 1.year.from_now,
        custom_fields: {
          DiscourseCalendar::REGION_CUSTOM_FIELD => "fr",
        },
      )

    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    expect(CalendarEvent.pluck(:region, :description, :start_date, :user_id)).to eq([])
  end

  it "does not create duplicates when username is changed" do
    frenchy
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)
    created_event = CalendarEvent.last
    expect(created_event.username).to eq(frenchy.username)
    frenchy.update!(username: "new_username")

    expect { DiscourseCalendar::CreateHolidayEvents.new.execute(nil) }.not_to change {
      CalendarEvent.count
    }
    expect(created_event.reload.username).to eq("new_username")
  end

  it "does not create duplicates when timezone is changed" do
    frenchy
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)
    created_event = CalendarEvent.last
    expect(created_event.timezone).to eq(frenchy.user_option.timezone)
    frenchy.user_option.update!(timezone: "Asia/Taipei")

    expect { DiscourseCalendar::CreateHolidayEvents.new.execute(nil) }.not_to change {
      CalendarEvent.count
    }
    expect(created_event.reload.timezone).to eq("Asia/Taipei")
  end

  it "cleans up holidays from deactivated/silenced/suspended users" do
    frenchy
    freeze_time Time.zone.local(2019, 8, 1)
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    expect(CalendarEvent.exists?(user_id: frenchy.id)).to eq(true)

    frenchy.active = false
    frenchy.save!

    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    expect(CalendarEvent.exists?(user_id: frenchy.id)).to eq(false)
  end

  it "cleans up holidays from users who changed their region" do
    frenchy
    freeze_time Time.zone.local(2019, 8, 1)
    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    expect(CalendarEvent.exists?(user_id: frenchy.id)).to eq(true)

    frenchy.custom_fields[DiscourseCalendar::REGION_CUSTOM_FIELD] = "au"
    frenchy.save!

    freeze_time Time.zone.local(2020, 1, 1)

    DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

    # Past 'fr' holidays should not be removed
    expect(
      CalendarEvent
        .where(user: frenchy)
        .where(region: "fr")
        .where("start_date <= ?", Date.today)
        .exists?,
    ).to eq(true)

    # Future 'fr' holidays should be removed
    expect(
      CalendarEvent
        .where(user: frenchy)
        .where(region: "fr")
        .where("start_date > ?", Date.today)
        .exists?,
    ).to eq(false)

    # Future 'au' holidays should be added
    expect(
      CalendarEvent
        .where(user: frenchy)
        .where(region: "au")
        .where("start_date > ?", Date.today)
        .exists?,
    ).to eq(true)
  end

  context "when there are disabled holidays" do
    let(:france_assomption) { { holiday_name: "Assomption", region_code: "fr" } }
    let(:france_toussaint) { { holiday_name: "Toussaint", region_code: "fr" } }

    before do
      DiscourseCalendar::DisabledHoliday.create!(france_assomption)
      DiscourseCalendar::DisabledHoliday.create!(france_toussaint)
    end

    it "only adds enabled holidays to the calendar" do
      frenchy
      freeze_time Time.zone.local(2019, 7, 1)
      DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

      expect(CalendarEvent.pluck(:region, :description, :start_date, :user_id)).to match_array(
        [
          ["fr", "Armistice 1918", Date.parse("2019-11-11"), frenchy.id],
          ["fr", "Noël", Date.parse("2019-12-25"), frenchy.id],
          ["fr", "Jour de l'an", Date.parse("2020-01-01"), frenchy.id],
        ],
      )
    end

    it "doesn't add disabled holidays to the calendar" do
      frenchy
      freeze_time Time.zone.local(2019, 7, 1)
      DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

      expect(CalendarEvent.pluck(:description)).not_to include(france_assomption[:holiday_name])
      expect(CalendarEvent.pluck(:description)).not_to include(france_toussaint[:holiday_name])
    end
  end

  context "when user_options.timezone column exists" do
    it "uses the user TZ when available" do
      frenchy.user_option.update!(timezone: "Europe/Paris")
      freeze_time Time.zone.local(2019, 8, 1)
      DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

      calendar_event = CalendarEvent.first
      expect(calendar_event.region).to eq("fr")
      expect(calendar_event.description).to eq("Assomption")
      expect(calendar_event.start_date).to eq("2019-08-15T00:00:00+02:00")
      expect(calendar_event.user_id).to eq(frenchy.id)
      expect(calendar_event.username).to eq(frenchy.username)
    end

    describe "with all day event start and end time" do
      before do
        SiteSetting.all_day_event_start_time = "06:00"
        SiteSetting.all_day_event_end_time = "18:00"
      end

      it "uses the user TZ when available" do
        frenchy.user_option.update!(timezone: "Europe/Paris")
        freeze_time Time.zone.local(2019, 8, 1)
        DiscourseCalendar::CreateHolidayEvents.new.execute(nil)

        calendar_event = CalendarEvent.first
        expect(calendar_event.region).to eq("fr")
        expect(calendar_event.description).to eq("Assomption")
        expect(calendar_event.start_date).to eq("2019-08-15T06:00:00+02:00")
        expect(calendar_event.user_id).to eq(frenchy.id)
        expect(calendar_event.username).to eq(frenchy.username)
      end
    end
  end
end
