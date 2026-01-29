# frozen_string_literal: true

module DiscourseCalendar
  describe TeamAvailabilityController do
    fab!(:user)
    fab!(:admin)
    fab!(:group) { Fabricate(:group, name: "team") }
    fab!(:group_member1) { Fabricate(:user, username: "alice", groups: [group]) }
    fab!(:group_member2) { Fabricate(:user, username: "bob", groups: [group]) }
    fab!(:category)
    fab!(:holiday_topic) { Fabricate(:topic, category:) }

    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.holiday_calendar_topic_id = holiday_topic.id
      group.add(user)
    end

    describe "#index" do
      context "when not logged in" do
        it "requires authentication" do
          get "/availability.json"
          expect(response.status).to eq(403)
        end
      end

      context "when logged in" do
        before { sign_in(user) }

        context "with HTML format" do
          it "renders the page" do
            get "/availability"
            expect(response.status).to eq(200)
          end

          it "renders the page with group" do
            get "/availability/#{group.name}"
            expect(response.status).to eq(200)
          end
        end

        context "with JSON format" do
          it "returns error when no holiday topic configured" do
            SiteSetting.holiday_calendar_topic_id = 0
            get "/availability.json"
            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).to eq("no_topic_configured")
          end

          it "returns error when holiday topic not found" do
            SiteSetting.holiday_calendar_topic_id = 999_999
            get "/availability.json"
            expect(response.status).to eq(200)
            expect(response.parsed_body["error"]).to eq("topic_not_found")
          end

          it "returns members with events" do
            CalendarEvent.create!(
              topic_id: holiday_topic.id,
              post_id: Fabricate(:post, topic: holiday_topic).id,
              user_id: group_member1.id,
              description: "#leave vacation",
              start_date: Time.current.beginning_of_week(:monday),
              end_date: Time.current.beginning_of_week(:monday) + 3.days,
            )

            get "/availability.json"

            expect(response.status).to eq(200)
            body = response.parsed_body
            expect(body["members"]).to be_present
            expect(body["events_by_member"]).to be_present
            expect(body["groups"]).to be_present
          end

          it "returns user's groups" do
            get "/availability.json"

            expect(response.status).to eq(200)
            body = response.parsed_body
            group_names = body["groups"].map { |g| g["name"] }
            expect(group_names).to include(group.name)
          end

          context "with group filter" do
            it "returns error for non-existent group" do
              get "/availability.json", params: { group_name: "nonexistent" }
              expect(response.status).to eq(200)
              expect(response.parsed_body["error"]).to eq("group_not_found")
            end

            it "returns all group members" do
              get "/availability.json", params: { group_name: group.name }

              expect(response.status).to eq(200)
              body = response.parsed_body
              usernames = body["members"].map { |m| m["username"] }
              expect(usernames).to include("alice", "bob")
            end

            it "includes member timezone" do
              group_member1.user_option.update!(timezone: "America/New_York")

              get "/availability.json", params: { group_name: group.name }

              expect(response.status).to eq(200)
              body = response.parsed_body
              alice = body["members"].find { |m| m["username"] == "alice" }
              expect(alice["timezone"]).to eq("America/New_York")
            end
          end

          context "with events" do
            fab!(:post) { Fabricate(:post, topic: holiday_topic, user: group_member1) }

            before do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#leave summer vacation",
                start_date: Time.current.beginning_of_week(:monday) + 1.day,
                end_date: Time.current.beginning_of_week(:monday) + 5.days,
              )
            end

            it "returns events grouped by member" do
              get "/availability.json"

              expect(response.status).to eq(200)
              body = response.parsed_body
              events = body["events_by_member"][group_member1.id.to_s]
              expect(events).to be_present
              expect(events.first["type"]).to eq("leave")
              expect(events.first["message"]).to include("#leave")
            end

            it "includes post_url for events with posts" do
              get "/availability.json"

              expect(response.status).to eq(200)
              body = response.parsed_body
              events = body["events_by_member"][group_member1.id.to_s]
              expect(events.first["post_url"]).to be_present
            end
          end

          context "with public holidays" do
            before do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: nil,
                user_id: group_member1.id,
                description: "Christmas Day",
                start_date: Time.current.beginning_of_week(:monday) + 2.days,
                end_date: nil,
              )
            end

            it "returns public holidays" do
              get "/availability.json"

              expect(response.status).to eq(200)
              body = response.parsed_body
              events = body["events_by_member"][group_member1.id.to_s]
              expect(events).to be_present
              expect(events.first["type"]).to eq("public-holiday")
            end

            it "does not include post_url for public holidays" do
              get "/availability.json"

              expect(response.status).to eq(200)
              body = response.parsed_body
              events = body["events_by_member"][group_member1.id.to_s]
              expect(events.first["post_url"]).to be_nil
            end
          end

          context "with event type detection" do
            fab!(:post) { Fabricate(:post, topic: holiday_topic, user: group_member1) }

            it "detects leave type" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#leave vacation",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("leave")
            end

            it "detects sick type" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#sick not feeling well",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("sick")
            end

            it "detects family-reasons type" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#family-reasons child is sick",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("family-reasons")
            end

            it "detects work type" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#work business trip",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("work")
            end

            it "detects parental-leave type" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#parental-leave new baby",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("parental-leave")
            end

            it "handles hashtag with parentheses" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#leave(2d) vacation",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("leave")
            end

            it "returns default type for unknown hashtags" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "#unknown some event",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("default")
            end

            it "returns default type for events without hashtags" do
              CalendarEvent.create!(
                topic_id: holiday_topic.id,
                post_id: post.id,
                user_id: group_member1.id,
                description: "just a regular event",
                start_date: Time.current.beginning_of_week(:monday),
              )

              get "/availability.json"

              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events.first["type"]).to eq("default")
            end
          end

          context "with date range filtering" do
            fab!(:post) { Fabricate(:post, topic: holiday_topic, user: group_member1) }

            it "returns events within the requested date range" do
              start_of_week = Time.current.beginning_of_week(:monday)

              within_range =
                CalendarEvent.create!(
                  topic_id: holiday_topic.id,
                  post_id: post.id,
                  user_id: group_member1.id,
                  description: "#leave within range",
                  start_date: start_of_week + 1.day,
                  end_date: start_of_week + 3.days,
                )

              out_of_range =
                CalendarEvent.create!(
                  topic_id: holiday_topic.id,
                  post_id: Fabricate(:post, topic: holiday_topic).id,
                  user_id: group_member1.id,
                  description: "#leave out of range",
                  start_date: start_of_week + 30.days,
                  end_date: start_of_week + 32.days,
                )

              get "/availability.json",
                  params: {
                    start_date: start_of_week.to_date.to_s,
                    end_date: (start_of_week + 14.days).to_date.to_s,
                  }

              expect(response.status).to eq(200)
              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              messages = events.map { |e| e["message"] }
              expect(messages).to include("#leave within range")
              expect(messages).not_to include("#leave out of range")
            end

            it "defaults to current week when no date range provided" do
              start_of_week = Time.current.beginning_of_week(:monday)

              current_event =
                CalendarEvent.create!(
                  topic_id: holiday_topic.id,
                  post_id: post.id,
                  user_id: group_member1.id,
                  description: "#leave current week",
                  start_date: start_of_week + 1.day,
                  end_date: start_of_week + 3.days,
                )

              get "/availability.json"

              expect(response.status).to eq(200)
              events = response.parsed_body["events_by_member"][group_member1.id.to_s]
              expect(events).to be_present
            end
          end

          context "when user cannot see holiday topic" do
            before do
              holiday_topic.update!(category: Fabricate(:private_category, group:))
              group.remove(user)
            end

            it "returns forbidden" do
              get "/availability.json"
              expect(response.status).to eq(403)
            end
          end

          context "when user cannot see group" do
            fab!(:private_group) do
              Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
            end

            it "returns forbidden" do
              get "/availability.json", params: { group_name: private_group.name }
              expect(response.status).to eq(403)
            end
          end
        end
      end
    end
  end
end
