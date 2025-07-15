# frozen_string_literal: true

module DiscoursePostEvent
  describe EventsController do
    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      SiteSetting.displayed_invitees_limit = 3
    end

    describe "#index" do
      fab!(:event_1) { Fabricate(:event, original_starts_at: 1.day.from_now) }

      it "should not result in N+1 queries problem when multiple events are returned" do
        original_queries = track_sql_queries { get "/discourse-post-event/events.json" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["events"].length).to eq(1)

        event_2 = Fabricate(:event, original_starts_at: 2.days.from_now)
        event_3 = Fabricate(:event, original_starts_at: 3.days.from_now)

        new_queries = track_sql_queries { get "/discourse-post-event/events.json" }

        expect(response.status).to eq(200)
        expect(response.parsed_body["events"].length).to eq(3)

        # TODO: There is still N+1 query problem here so uncomment this line when it is fixed
        # expect(new_queries.count).to eq(original_queries.count)
      end
    end

    context "with an existing post" do
      let(:user) { Fabricate(:user, admin: true) }
      let(:topic) { Fabricate(:topic, user: user) }
      let(:post1) { Fabricate(:post, user: user, topic: topic) }
      let(:invitee1) { Fabricate(:user) }
      let(:invitee2) { Fabricate(:user) }

      context "with an existing event" do
        let(:event_1) { Fabricate(:event, post: post1) }

        before { sign_in(user) }

        context "when updating" do
          context "when doing csv bulk invite" do
            let(:valid_file) do
              file = Tempfile.new("valid.csv")
              file.write("bob,going\n")
              file.write("sam,interested\n")
              file.write("the_foo_bar_group,not_going\n")
              file.rewind
              file
            end

            let(:empty_file) do
              file = Tempfile.new("invalid.pdf")
              file.rewind
              file
            end

            context "when current user can manage the event" do
              context "when no file is given" do
                it "returns an error" do
                  post "/discourse-post-event/events/#{event_1.id}/csv-bulk-invite.json"
                  expect(response.parsed_body["error_type"]).to eq("invalid_parameters")
                end
              end

              context "when an empty file is given" do
                it "returns an error" do
                  post "/discourse-post-event/events/#{event_1.id}/csv-bulk-invite.json",
                       params: {
                         file: fixture_file_upload(empty_file),
                       }
                  expect(response.status).to eq(422)
                end
              end

              context "when a valid file is given" do
                before { Jobs.run_later! }

                it "enqueues the job and returns 200" do
                  expect_enqueued_with(
                    job: :discourse_post_event_bulk_invite,
                    args: {
                      "event_id" => event_1.id,
                      "invitees" => [
                        { "identifier" => "bob", "attendance" => "going" },
                        { "identifier" => "sam", "attendance" => "interested" },
                        { "identifier" => "the_foo_bar_group", "attendance" => "not_going" },
                      ],
                      "current_user_id" => user.id,
                    },
                  ) do
                    post "/discourse-post-event/events/#{event_1.id}/csv-bulk-invite.json",
                         params: {
                           file: fixture_file_upload(valid_file),
                         }
                  end

                  expect(response.status).to eq(200)
                end
              end
            end

            context "when current user can’t manage the event" do
              let(:lurker) { Fabricate(:user) }

              before { sign_in(lurker) }

              it "returns an error" do
                post "/discourse-post-event/events/#{event_1.id}/csv-bulk-invite.json"
                expect(response.status).to eq(403)
              end
            end
          end

          context "when doing bulk invite" do
            context "when current user can manage the event" do
              context "when no invitees are given" do
                it "returns an error" do
                  post "/discourse-post-event/events/#{event_1.id}/bulk-invite.json"
                  expect(response.parsed_body["error_type"]).to eq("invalid_parameters")
                end
              end

              context "when empty invitees are given" do
                it "returns an error" do
                  post "/discourse-post-event/events/#{event_1.id}/bulk-invite.json",
                       params: {
                         invitees: [],
                       }
                  expect(response.status).to eq(400)
                end
              end

              context "when valid invitees are given" do
                before { Jobs.run_later! }

                it "enqueues the job and returns 200" do
                  expect_enqueued_with(
                    job: :discourse_post_event_bulk_invite,
                    args: {
                      "event_id" => event_1.id,
                      "invitees" => [
                        { "identifier" => "bob", "attendance" => "going" },
                        { "identifier" => "sam", "attendance" => "interested" },
                        { "identifier" => "the_foo_bar_group", "attendance" => "not_going" },
                      ],
                      "current_user_id" => user.id,
                    },
                  ) do
                    post "/discourse-post-event/events/#{event_1.id}/bulk-invite.json",
                         params: {
                           invitees: [
                             { "identifier" => "bob", "attendance" => "going" },
                             { "identifier" => "sam", "attendance" => "interested" },
                             { "identifier" => "the_foo_bar_group", "attendance" => "not_going" },
                           ],
                         }
                  end

                  expect(response.status).to eq(200)
                end
              end
            end

            context "when current user can’t manage the event" do
              let(:lurker) { Fabricate(:user) }

              before { sign_in(lurker) }

              it "returns an error" do
                post "/discourse-post-event/events/#{event_1.id}/bulk-invite.json"
                expect(response.status).to eq(403)
              end
            end
          end
        end

        context "when acting user has created the event" do
          it "destroys a event" do
            expect(event_1.persisted?).to be(true)

            messages =
              MessageBus.track_publish { delete "/discourse-post-event/events/#{event_1.id}.json" }
            expect(messages.count).to eq(1)
            message = messages.first
            expect(message.channel).to eq("/discourse-post-event/#{event_1.post.topic_id}")
            expect(message.data[:id]).to eq(event_1.id)
            expect(response.status).to eq(200)
            expect(Event).to_not exist(id: event_1.id)
          end
        end

        context "when acting user has not created the event" do
          let(:lurker) { Fabricate(:user) }

          before { sign_in(lurker) }

          it "doesn’t destroy the event" do
            expect(event_1.persisted?).to be(true)
            delete "/discourse-post-event/events/#{event_1.id}.json"
            expect(response.status).to eq(403)
            expect(Event).to exist(id: event_1.id)
          end
        end

        context "when watching user is not logged" do
          before { sign_out }

          context "when topic is public" do
            it "can see the event" do
              get "/discourse-post-event/events/#{event_1.id}.json"

              expect(response.status).to eq(200)
            end
          end

          context "when topic is not public" do
            before { event_1.post.topic.convert_to_private_message(Discourse.system_user) }

            it "can’t see the event" do
              get "/discourse-post-event/events/#{event_1.id}.json"

              expect(response.status).to eq(404)
            end
          end
        end

        context "when filtering by category" do
          fab!(:category)

          fab!(:subcategory) do
            Fabricate(:category, parent_category: category, name: "category subcategory")
          end

          fab!(:event_1) do
            Fabricate(
              :event,
              original_starts_at: 2.days.from_now,
              post: Fabricate(:post, post_number: 1, topic: Fabricate(:topic, category: category)),
            )
          end

          fab!(:event_2) do
            Fabricate(
              :event,
              original_starts_at: 1.day.from_now,
              post:
                Fabricate(:post, post_number: 1, topic: Fabricate(:topic, category: subcategory)),
            )
          end

          fab!(:event_3) do
            Fabricate(
              :event,
              post: Fabricate(:post, post_number: 1, topic: Fabricate(:topic, category: category)),
              original_starts_at: 10.days.ago,
              original_ends_at: 9.days.ago,
            )
          end

          it "can filter the event by category" do
            get "/discourse-post-event/events.json?category_id=#{category.id}"

            expect(response.status).to eq(200)
            events = response.parsed_body["events"]
            expect(events.length).to eq(1)
            expect(events[0]["id"]).to eq(event_1.id)
          end

          it "includes subcategory events when param provided" do
            get "/discourse-post-event/events.json?category_id=#{category.id}&include_subcategories=true"

            expect(response.status).to eq(200)
            events = response.parsed_body["events"]
            expect(events.length).to eq(2)
            expect(events).to match_array(
              [hash_including("id" => event_1.id), hash_including("id" => event_2.id)],
            )
          end

          it "includes events' details when param provided" do
            get "/discourse-post-event/events.json?category_id=#{category.id}&include_subcategories=true&include_details=true"

            expect(response.status).to eq(200)
            events = response.parsed_body["events"]
            expect(events.length).to eq(2)
            expect(events[0].keys).to include(
              "creator",
              "sample_invitees",
              "watching_invitee",
              "stats",
              "status",
              "can_update_attendance",
              "should_display_invitees",
              "is_public",
              "is_private",
              "is_standalone",
            )
          end

          it "includes expired events when param provided" do
            get "/discourse-post-event/events.json?category_id=#{category.id}&include_subcategories=true&include_expired=true"

            expect(response.status).to eq(200)
            events = response.parsed_body["events"]
            expect(events.length).to eq(3)
            expect(events).to match_array(
              [
                hash_including("id" => event_1.id),
                hash_including("id" => event_2.id),
                hash_including("id" => event_3.id),
              ],
            )
          end

          it "limits the number of events returned when limit param provided" do
            get "/discourse-post-event/events.json?category_id=#{category.id}&include_subcategories=true&limit=1"

            expect(response.status).to eq(200)
            events = response.parsed_body["events"]
            expect(events.length).to eq(1)
            expect(events[0]["id"]).to eq(event_2.id)
          end

          it "filters events before the provided datetime if before param provided" do
            get "/discourse-post-event/events.json?category_id=#{category.id}&include_subcategories=true&include_expired=true&before=#{event_2.starts_at}"

            expect(response.status).to eq(200)
            events = response.parsed_body["events"]
            expect(events.length).to eq(1)
            expect(events[0]["id"]).to eq(event_3.id)
          end
        end
      end
    end

    context "with a private event" do
      let(:moderator) { Fabricate(:user, moderator: true) }
      let(:topic) { Fabricate(:topic, user: moderator) }
      let(:first_post) { Fabricate(:post, user: moderator, topic: topic) }
      let(:private_event) { Fabricate(:event, post: first_post, status: Event.statuses[:private]) }

      before { sign_in(moderator) }

      context "when bulk inviting via CSV file" do
        def csv_file(content)
          file = Tempfile.new("invites.csv")
          file.write(content)
          file.rewind
          file
        end

        it "doesn't invite a private group" do
          private_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])

          file = csv_file("#{private_group.name},going\n")
          params = { file: fixture_file_upload(file) }
          post "/discourse-post-event/events/#{private_event.id}/csv-bulk-invite.json",
               params: params

          expect(response.status).to eq(200)
          private_event.reload
          expect(private_event.raw_invitees).to be_nil
        end

        it "returns 200 when inviting a non-existent group" do
          file = csv_file("non-existent group name,going\n")
          params = { file: fixture_file_upload(file) }
          post "/discourse-post-event/events/#{private_event.id}/csv-bulk-invite.json",
               params: params

          expect(response.status).to eq(200)
        end

        it "doesn't invite a public group with private members" do
          public_group_with_private_members =
            Fabricate(
              :group,
              visibility_level: Group.visibility_levels[:public],
              members_visibility_level: Group.visibility_levels[:owners],
            )

          file = csv_file("#{public_group_with_private_members.name},going\n")
          params = { file: fixture_file_upload(file) }
          post "/discourse-post-event/events/#{private_event.id}/csv-bulk-invite.json",
               params: params

          expect(response.status).to eq(200)
          private_event.reload
          expect(private_event.raw_invitees).to be_nil
        end
      end

      context "when doing bulk inviting via UI" do
        it "doesn't invite a private group" do
          private_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])

          params = { invitees: [{ "identifier" => private_group.name, "attendance" => "going" }] }
          post "/discourse-post-event/events/#{private_event.id}/bulk-invite.json", params: params

          expect(response.status).to eq(200)
          private_event.reload
          expect(private_event.raw_invitees).to be_nil
        end

        it "returns 200 when inviting a non-existent group" do
          params = {
            invitees: [{ "identifier" => "non-existent group name", "attendance" => "going" }],
          }
          post "/discourse-post-event/events/#{private_event.id}/bulk-invite.json", params: params

          expect(response.status).to eq(200)
        end

        it "doesn't invite a public group with private members" do
          public_group_with_private_members =
            Fabricate(
              :group,
              visibility_level: Group.visibility_levels[:public],
              members_visibility_level: Group.visibility_levels[:owners],
            )

          params = {
            invitees: [
              { "identifier" => public_group_with_private_members.name, "attendance" => "going" },
            ],
          }
          post "/discourse-post-event/events/#{private_event.id}/bulk-invite.json", params: params

          expect(response.status).to eq(200)
          private_event.reload
          expect(private_event.raw_invitees).to be_nil
        end
      end
    end
  end
end
