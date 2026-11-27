# frozen_string_literal: true

RSpec.describe DiscourseEvents::EventsController do
  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    freeze_time Time.utc(2026, 11, 27)
  end

  describe "#agenda" do
    it "rate limits anonymous agenda requests per IP without limiting other views" do
      RateLimiter.enable
      params = { after: "2026-01-01", before: "2027-01-01" }
      30.times do
        get "/discourse-post-event/events/agenda.json", params: params
        expect(response.status).to eq(200)
      end

      get "/discourse-post-event/events/agenda.json", params: params

      expect(response.status).to eq(429)
      expect(response.headers["Retry-After"]).to be_present

      get "/discourse-post-event/events/agenda.json",
          params: params,
          headers: {
            "REMOTE_ADDR" => "203.0.113.1",
          }
      expect(response.status).to eq(200)

      get "/discourse-post-event/events.json", params: params
      expect(response.status).to eq(200)

      freeze_time 61.seconds.from_now
      get "/discourse-post-event/events/agenda.json", params: params
      expect(response.status).to eq(200)
    end

    it "rate limits signed-in agenda requests by account" do
      sign_in(Fabricate(:user))
      RateLimiter.enable
      params = { after: "2026-01-01", before: "2027-01-01" }
      30.times { get "/discourse-post-event/events/agenda.json", params: params }

      get "/discourse-post-event/events/agenda.json",
          params: params,
          headers: {
            "REMOTE_ADDR" => "203.0.113.1",
          }

      expect(response.status).to eq(429)

      sign_in(Fabricate(:user))
      get "/discourse-post-event/events/agenda.json", params: params
      expect(response.status).to eq(200)
    end

    it "prunes recurring series outside the requested side before instantiating them" do
      earlier =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 1, 1),
          original_ends_at: nil,
          recurrence: "every_week",
          recurrence_until: Time.utc(2026, 3, 1),
        )
      later =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 10, 1),
          original_ends_at: nil,
          recurrence: "every_week",
        )
      %w[earlier later].each do |direction|
        [
          { anchor: "2026-07-01" },
          {
            anchor: direction == "earlier" ? "2027-01-01" : "2026-01-01",
            cursor_time: "2026-07-01T00:00:00Z",
            cursor_id: 1,
          },
        ].each do |position|
          loaded_events = 0
          subscriber = ->(*args) do
            payload = args.last
            loaded_events += payload[:record_count] if payload[:class_name] ==
              "DiscourseEvents::Events::Event"
          end
          ActiveSupport::Notifications.subscribed(subscriber, "instantiation.active_record") do
            get "/discourse-post-event/events/agenda.json",
                params: {
                  after: "2026-01-01",
                  before: "2027-01-01",
                  direction:,
                  **position,
                }
          end

          expect(response.status).to eq(200)
          expect(response.parsed_body["events"].map { |event| event["id"] }).to eq(
            [direction == "earlier" ? earlier.id : later.id],
          )
          expect(loaded_events).to eq(1)
        end
      end
    end

    it "keeps the final recurring occurrence while it is still ongoing" do
      event =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 16),
          original_ends_at: Time.utc(2026, 11, 21),
          recurrence: "every_week",
          recurrence_until: Time.utc(2026, 11, 23),
        )

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-01-01",
            before: "2027-01-01",
            anchor: "2026-11-27",
            timezone: "UTC",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
      expect(response.parsed_body["events"].first["occurrences"]).to eq(
        [{ "starts_at" => "2026-11-23T00:00:00.000Z", "ends_at" => "2026-11-28T00:00:00.000Z" }],
      )
    end

    it "keeps floating final occurrences across the extreme timezone offsets" do
      events =
        %w[Pacific/Kiritimati Etc/GMT+12].map do |timezone|
          final_start = Time.find_zone!(timezone).local(2026, 11, 27)
          Fabricate(
            :event,
            original_starts_at: final_start - 1.week,
            original_ends_at: nil,
            recurrence: "every_week",
            recurrence_until: final_start.end_of_day,
            timezone:,
            show_local_time: true,
          )
        end

      %w[Pacific/Kiritimati Etc/GMT+12].each do |timezone|
        zone = Time.find_zone!(timezone)
        get "/discourse-post-event/events/agenda.json",
            params: {
              after: zone.local(2026, 1, 1).iso8601,
              before: zone.local(2027, 1, 1).iso8601,
              anchor: zone.local(2026, 11, 27).iso8601,
              timezone:,
            }

        expect(response.status).to eq(200)
        expect(response.parsed_body["events"].map { |event| event["id"] }).to contain_exactly(
          *events.map(&:id),
        )
        expect(
          response.parsed_body["events"].flat_map do |event|
            event["occurrences"].map { |occurrence| occurrence["starts_at"] }
          end,
        ).to eq(%w[2026-11-27T00:00:00 2026-11-27T00:00:00])
      end
    end

    it "keeps an end-less all-day series on the correct side of the anchor" do
      event =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 19),
          original_ends_at: nil,
          recurrence: "every_week",
          recurrence_until: Time.utc(2026, 11, 26),
          all_day: true,
        )
      params = {
        after: "2026-01-01T00:00:00-03:00",
        before: "2027-01-01T00:00:00-03:00",
        anchor: "2026-11-27T00:00:00-03:00",
        timezone: "America/Sao_Paulo",
      }

      get "/discourse-post-event/events/agenda.json", params: params
      expect(response.parsed_body["events"]).to eq([])

      get "/discourse-post-event/events/agenda.json", params: params.merge(direction: "earlier")
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
      expect(response.parsed_body["events"].first["occurrences"].last["starts_at"]).to eq(
        "2026-11-26",
      )
    end

    it "keeps earlier floating occurrences whose UTC start is after the anchor instant" do
      event =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 27),
          original_ends_at: nil,
          recurrence: "every_week",
          timezone: "Etc/GMT+12",
          show_local_time: true,
        )

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-01-01T00:00:00+13:00",
            before: "2027-01-01T00:00:00+13:00",
            anchor: "2026-11-27T00:00:00+13:00",
            timezone: "Pacific/Auckland",
            direction: "earlier",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
      expect(response.parsed_body["events"].first["occurrences"].first["starts_at"]).to eq(
        "2026-11-26T12:00:00",
      )
    end

    it "uses displayed dates at both year boundaries for all-day and floating events" do
      events =
        [Time.utc(2026, 1, 1), Time.utc(2026, 12, 31), Time.utc(2027, 1, 1)].flat_map do |date|
          [
            Fabricate(:event, original_starts_at: date, original_ends_at: nil, all_day: true),
            Fabricate(
              :event,
              original_starts_at: date - 14.hours,
              original_ends_at: nil,
              timezone: "Pacific/Kiritimati",
              show_local_time: true,
            ),
            Fabricate(
              :event,
              original_starts_at: date,
              original_ends_at: nil,
              all_day: true,
              recurrence: "every_week",
              recurrence_until: date + 1.day,
            ),
          ]
        end

      %w[-03:00 +13:00].each do |offset|
        [2026, 2027].each do |year|
          get "/discourse-post-event/events/agenda.json",
              params: {
                after: "#{year}-01-01T00:00:00#{offset}",
                before: "#{year + 1}-01-01T00:00:00#{offset}",
              }

          expect(response.status).to eq(200)
          expected = year == 2026 ? events.first(6) : events.last(3)
          expect(response.parsed_body["events"].map { |event| event["id"] }).to contain_exactly(
            *expected.map(&:id),
          )
          expect(response.parsed_body["has_later"]).to eq(false)
        end
      end
    end

    it "keeps today's all-day and floating-time events on the upcoming side in both UTC offsets" do
      all_day =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 27),
          original_ends_at: nil,
          all_day: true,
        )
      floating =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 27, 1),
          original_ends_at: nil,
          timezone: "UTC",
          show_local_time: true,
        )
      past =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 26),
          original_ends_at: nil,
          all_day: true,
        )

      %w[-03:00 +13:00].each do |offset|
        params = {
          after: "2026-01-01T00:00:00#{offset}",
          before: "2027-01-01T00:00:00#{offset}",
          anchor: "2026-11-27T00:00:00#{offset}",
        }
        get "/discourse-post-event/events/agenda.json", params: params

        expect(response.status).to eq(200)
        expect(response.parsed_body["events"].map { |event| event["id"] }).to contain_exactly(
          all_day.id,
          floating.id,
        )
        expect(response.parsed_body["has_earlier"]).to eq(true)

        get "/discourse-post-event/events/agenda.json", params: params.merge(direction: "earlier")

        expect(response.parsed_body["events"].map { |event| event["id"] }).to eq([past.id])
      end
    end

    it "paginates mixed floating and timed events in their displayed order" do
      topic = Fabricate(:topic)
      200.times do
        Fabricate(
          :event,
          post: Fabricate(:post, topic:),
          original_starts_at: Time.utc(2026, 11, 28, 1),
        )
      end
      floating =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 28, 4),
          timezone: "America/New_York",
          show_local_time: true,
        )
      params = { after: "2026-01-01", before: "2027-01-01", anchor: "2026-11-27", timezone: "UTC" }

      get "/discourse-post-event/events/agenda.json", params: params

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].first["id"]).to eq(floating.id)
      expect(response.parsed_body["events"].size).to eq(200)
      cursor = response.parsed_body["next_cursor"]
      get "/discourse-post-event/events/agenda.json",
          params: params.merge(cursor_time: cursor["time"], cursor_id: cursor["id"])

      expect(response.parsed_body["events"].size).to eq(1)
      expect(response.parsed_body["events"].first["id"]).not_to eq(floating.id)
      expect(response.parsed_body["has_later"]).to eq(false)
    end

    it "accepts Rails timezone aliases for floating-time events" do
      event =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 28, 4),
          timezone: "Eastern Time (US & Canada)",
          show_local_time: true,
        )

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-01-01",
            before: "2027-01-01",
            anchor: "2026-11-27",
            timezone: "UTC",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
      expect(response.parsed_body["events"].first["occurrences"].first["starts_at"]).to eq(
        "2026-11-27T23:00:00",
      )
    end

    it "keeps serialization query counts constant as occurrences increase" do
      Fabricate(:event, original_starts_at: Time.utc(2026, 1, 1, 10), recurrence: "every_day")
      params = { after: "2026-01-01", before: "2026-01-02" }
      get "/discourse-post-event/events/agenda.json", params: params

      one_occurrence =
        track_sql_queries { get "/discourse-post-event/events/agenda.json", params: params }
      expect(response.parsed_body["events"].size).to eq(1)

      many_occurrences =
        track_sql_queries do
          get "/discourse-post-event/events/agenda.json", params: params.merge(before: "2027-01-01")
        end
      expect(response.parsed_body["events"].size).to eq(1)
      expect(response.parsed_body["events"].first["occurrences"].size).to eq(200)
      expect(many_occurrences.size).to eq(one_occurrence.size)
    end

    it "allows an earlier request and skips empty months" do
      past = Fabricate(:event, original_starts_at: Time.utc(2026, 2, 1))
      future = Fabricate(:event, original_starts_at: Time.utc(2026, 12, 31))
      Fabricate(:event, original_starts_at: Time.utc(2027, 1, 2))
      params = { after: "2026-01-01", before: "2027-01-01", anchor: "2026-11-27" }

      get "/discourse-post-event/events/agenda.json", params: params

      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([future.id])
      expect(response.parsed_body).to include("has_earlier" => true, "has_later" => false)

      get "/discourse-post-event/events/agenda.json", params: params.merge(direction: "earlier")

      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([past.id])
      expect(response.parsed_body["has_earlier"]).to eq(false)
    end

    it "reports exhaustion for an empty year" do
      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-01-01",
            before: "2027-01-01",
            anchor: "2026-11-27",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body).to include(
        "events" => [],
        "has_earlier" => true,
        "has_later" => false,
      )

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-01-01",
            before: "2027-01-01",
            anchor: "2026-11-27",
            direction: "earlier",
          }
      expect(response.parsed_body["has_earlier"]).to eq(false)
    end

    it "allows one empty request after an exactly full page in either direction" do
      Fabricate(
        :event,
        original_starts_at: Time.utc(2026, 1, 1, 10),
        recurrence: "every_day",
        recurrence_until: Time.utc(2026, 7, 19, 10),
      )
      %w[later earlier].each do |direction|
        params = { after: "2026-01-01", before: "2027-01-01", direction: }
        get "/discourse-post-event/events/agenda.json", params: params
        expect(response.status).to eq(200)
        expect(response.parsed_body["events"].sum { |event| event["occurrences"].size }).to eq(200)
        expect(response.parsed_body["has_#{direction}"]).to eq(true)
        cursor = response.parsed_body["next_cursor"]
        get "/discourse-post-event/events/agenda.json",
            params: params.merge(cursor_time: cursor["time"], cursor_id: cursor["id"])
        expect(response.status).to eq(200)
        expect(response.parsed_body["events"]).to eq([])
        expect(response.parsed_body["has_#{direction}"]).to eq(false)
        expect(response.parsed_body["next_cursor"]).to be_nil
      end
    end

    it "merges recurring batches with ordinary events in both directions" do
      recurring =
        [12, 10, 9].map do |hour|
          Fabricate(:event, original_starts_at: Time.utc(2026, 1, 1, hour), recurrence: "every_day")
        end
      single = Fabricate(:event, original_starts_at: Time.utc(2026, 1, 2, 11))
      expected =
        recurring.flat_map do |event|
          365.times.map { |day| [(event.original_starts_at + day.days).to_i, event.id] }
        end
      expected << [single.original_starts_at.to_i, single.id]
      expected.sort!

      stub_const(DiscourseEvents::Events::Agenda, :RECURRING_BATCH_SIZE, 2) do
        %w[later earlier].each do |direction|
          params = { after: "2026-01-01", before: "2027-01-01", direction: }
          collected = []
          6.times do
            get "/discourse-post-event/events/agenda.json", params: params
            expect(response.status).to eq(200)
            page =
              response.parsed_body["events"]
                .flat_map do |event|
                  event["occurrences"].map do |occurrence|
                    [Time.iso8601(occurrence["starts_at"]).to_i, event["id"]]
                  end
                end
                .sort
            direction == "later" ? collected.concat(page) : collected.prepend(*page)
            cursor = response.parsed_body["next_cursor"]
            break unless cursor
            params.merge!(cursor_time: cursor["time"], cursor_id: cursor["id"])
          end
          expect(collected).to eq(expected)
        end
      end
    end

    it "paginates all daily occurrences through the end of the year" do
      Fabricate(:event, original_starts_at: Time.utc(2026, 1, 1, 10), recurrence: "every_day")
      params = { after: "2026-01-01", before: "2027-01-01" }
      dates = []
      2.times do
        get "/discourse-post-event/events/agenda.json", params: params
        expect(response.status).to eq(200)
        dates.concat(
          response.parsed_body["events"].flat_map do |event|
            event["occurrences"].map { |occurrence| occurrence["starts_at"] }
          end,
        )
        cursor = response.parsed_body["next_cursor"]
        break unless cursor
        params.merge!(cursor_time: cursor["time"], cursor_id: cursor["id"])
      end
      expect(dates.uniq.size).to eq(365)
      expect(response.parsed_body["has_later"]).to eq(false)
    end

    it "excludes inaccessible events without a category filter" do
      event = Fabricate(:event)
      Fabricate(:private_event)

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-11-27",
            before: "2026-12-27",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
    end

    it "limits a single-occurrence RSVP to the current occurrence in My events" do
      user = Fabricate(:user)
      event =
        Fabricate(:event, original_starts_at: Time.utc(2026, 11, 28, 10), recurrence: "every_week")
      Fabricate(:event)
      event.create_invitees(
        [
          {
            user_id: user.id,
            status: DiscourseEvents::Events::Invitee.statuses[:going],
            recurring: false,
          },
        ],
      )
      sign_in(user)

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-11-27",
            before: "2026-12-27",
            attending_user: user.username,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
    end

    it "excludes a single-occurrence RSVP whose current date is outside the selected year" do
      user = Fabricate(:user)
      event =
        Fabricate(:event, original_starts_at: Time.utc(2026, 11, 28, 10), recurrence: "every_week")
      event.create_invitees(
        [
          {
            user_id: user.id,
            status: DiscourseEvents::Events::Invitee.statuses[:going],
            recurring: false,
          },
        ],
      )
      event.event_dates.update_all(starts_at: Time.utc(2027, 1, 2, 10))
      sign_in(user)

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-01-01",
            before: "2027-01-01",
            attending_user: user.username,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"]).to eq([])
    end

    it "seeks earlier recurring occurrences across a repeated DST hour" do
      topic = Fabricate(:topic)
      200.times do
        Fabricate(
          :event,
          post: Fabricate(:post, topic:),
          original_starts_at: Time.utc(2026, 11, 1, 5, 45),
        )
      end
      recurring =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 1, 6, 30),
          recurrence: "every_day",
          recurrence_until: Time.utc(2026, 11, 1, 6, 30),
          timezone: "UTC",
        )
      params = {
        after: "2026-01-01T00:00:00-05:00",
        before: "2027-01-01T00:00:00-05:00",
        anchor: "2026-11-02T00:00:00-05:00",
        timezone: "America/New_York",
        direction: "earlier",
      }
      get "/discourse-post-event/events/agenda.json", params: params
      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].size).to eq(200)
      cursor = response.parsed_body["next_cursor"]

      get "/discourse-post-event/events/agenda.json",
          params: params.merge(cursor_time: cursor["time"], cursor_id: cursor["id"])

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |event| event["id"] }).to eq([recurring.id])
    end

    it "pages more than 200 simultaneous occurrences in both directions without omissions" do
      topic = Fabricate(:topic)
      events =
        Array.new(201) do
          Fabricate(
            :event,
            post: Fabricate(:post, topic:),
            original_starts_at: Time.utc(2026, 12, 1),
          )
        end

      %w[later earlier].each do |direction|
        params = { after: "2026-11-27", before: "2026-12-27", direction: }
        ids = []
        2.times do |page|
          loaded_events = 0
          subscriber = ->(*args) do
            payload = args.last
            loaded_events += payload[:record_count] if payload[:class_name] ==
              "DiscourseEvents::Events::Event"
          end
          ActiveSupport::Notifications.subscribed(subscriber, "instantiation.active_record") do
            get "/discourse-post-event/events/agenda.json", params: params
          end
          expect(response.status).to eq(200)
          expect(loaded_events).to be <= 200
          batch = response.parsed_body["events"].map { |event| event["id"] }
          direction == "later" ? ids.concat(batch) : ids.prepend(*batch)
          cursor = response.parsed_body["next_cursor"]
          if page.zero?
            expect(batch.size).to eq(200)
            expect(cursor).to be_present
            params.merge!(cursor_time: cursor["time"], cursor_id: cursor["id"])
          else
            expect(batch.size).to eq(1)
            expect(cursor).to be_nil
          end
        end
        expect(ids).to eq(events.map(&:id))
      end
    end

    it "interleaves recurring occurrences with single events and includes ongoing events" do
      recurring =
        Fabricate(:event, original_starts_at: Time.utc(2026, 11, 20, 10), recurrence: "every_week")
      single = Fabricate(:event, original_starts_at: Time.utc(2026, 11, 28, 10))
      ongoing =
        Fabricate(
          :event,
          original_starts_at: Time.utc(2026, 11, 26),
          original_ends_at: Time.utc(2026, 11, 28),
        )
      Fabricate(:event, original_starts_at: Time.utc(2026, 11, 25))

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-11-27",
            before: "2026-12-10",
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |event| event["id"] }).to eq(
        [ongoing.id, recurring.id, single.id],
      )
      expect(
        response.parsed_body["events"].find { |event| event["id"] == recurring.id }[
          "occurrences"
        ].size,
      ).to eq(2)
      expect(response.parsed_body["next_cursor"]).to be_nil
    end

    it "retains daily recurring occurrences across adjacent windows" do
      event =
        Fabricate(:event, original_starts_at: Time.utc(2026, 11, 1, 10), recurrence: "every_day")
      occurrences = []
      [%w[2026-11-01 2026-12-01], %w[2026-12-01 2027-01-01]].each do |after, before|
        get "/discourse-post-event/events/agenda.json", params: { after:, before: }
        expect(response.status).to eq(200)
        occurrences.concat(response.parsed_body["events"].flat_map { |item| item["occurrences"] })
        expect(response.parsed_body["events"].map { |item| item["id"] }.uniq).to eq([event.id])
        expect(response.parsed_body["next_cursor"]).to be_nil
      end
      expect(occurrences.size).to eq(61)
      expect(occurrences.uniq.size).to eq(61)
    end

    it "preserves category permissions and filters" do
      category = Fabricate(:category)
      event = Fabricate(:event, post: Fabricate(:post, topic: Fabricate(:topic, category:)))
      Fabricate(:private_event)
      Fabricate(:event)

      get "/discourse-post-event/events/agenda.json",
          params: {
            after: "2026-11-27",
            before: "2026-12-27",
            category_id: category.id,
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["events"].map { |item| item["id"] }).to eq([event.id])
    end

    it "rejects invalid ranges and cursors" do
      [
        { before: "2028-11-27" },
        { before: "2026-11-26" },
        { direction: "invalid" },
        { cursor_time: "invalid", cursor_id: 1 },
        { cursor_time: "2026-11-28", cursor_id: "invalid" },
      ].each do |invalid|
        get "/discourse-post-event/events/agenda.json",
            params: { after: "2026-11-27", before: "2026-12-27" }.merge(invalid)
        expect(response.status).to eq(400)
      end
    end
  end
end
