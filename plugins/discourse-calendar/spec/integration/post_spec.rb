# frozen_string_literal: true

require "securerandom"

describe Post do
  before do
    freeze_time
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user, admin: true, refresh_auto_groups: true) }

  context "with a public event" do
    let(:post_1) { Fabricate(:post) }
    let(:event_1) { Fabricate(:event, post: post_1, raw_invitees: ["trust_level_0"]) }

    context "when a post is updated" do
      context "when the post has a valid event" do
        context "when the event markup is removed" do
          it "destroys the associated event" do
            start = Time.now.utc.iso8601(3)

            post = create_post_with_event(user)

            expect(post.reload.event.persisted?).to eq(true)

            revisor = PostRevisor.new(post, post.topic)
            revisor.revise!(user, raw: "The event is over. Come back another day.")

            expect(post.reload.event).to be(nil)
          end
        end

        context "when event is on going" do
          let(:going_user) { Fabricate(:user) }
          let(:interested_user) { Fabricate(:user) }

          before do
            SiteSetting.editing_grace_period = 1.minute
            PostActionNotifier.enable
            SiteSetting.discourse_post_event_edit_notifications_time_extension = 180
          end

          context "when in edit grace period" do
            before do
              event_1.event_dates.first.update_columns(starts_at: 3.hours.ago, ends_at: 2.hours.ago)

              # clean state
              Notification.destroy_all
              interested_user.reload
              going_user.reload
            end

            it "sends a post revision to going invitees" do
              DiscoursePostEvent::Invitee.create_attendance!(going_user.id, post_1.id, :going)
              DiscoursePostEvent::Invitee.create_attendance!(
                interested_user.id,
                post_1.id,
                :interested,
              )

              expect {
                revisor = PostRevisor.new(post_1)
                revisor.revise!(
                  user,
                  { raw: post_1.raw + "\nWe are bout half way into our event!" },
                  revised_at: Time.now + 2.minutes,
                )
              }.to change { going_user.notifications.count }.by(1)

              expect(interested_user.notifications.count).to eq(0)
            end
          end

          context "when not edit grace period" do
            before { event_1.event_dates.first.update_columns(starts_at: 5.hours.ago) }

            it "doesn’t send a post revision to anyone" do
              DiscoursePostEvent::Invitee.create_attendance!(going_user.id, post_1.id, :going)
              DiscoursePostEvent::Invitee.create_attendance!(
                interested_user.id,
                event_1.id,
                :interested,
              )

              expect {
                revisor = PostRevisor.new(event_1.post)
                revisor.revise!(
                  user,
                  { raw: event_1.post.raw + "\nWe are bout half way into our event!" },
                  revised_at: Time.now + 2.minutes,
                )
              }.to change {
                going_user.notifications.count + interested_user.notifications.count
              }.by(0)
            end
          end

          context "with an event with recurrence" do
            before do
              freeze_time Time.utc(2020, 8, 12, 16, 32)

              event_1.update_with_params!(
                recurrence: "FREQ=WEEKLY;BYDAY=MO",
                original_starts_at: 3.hours.ago,
                original_ends_at: nil,
              )

              DiscoursePostEvent::Invitee.create_attendance!(going_user.id, event_1.id, :going)
              DiscoursePostEvent::Invitee.create_attendance!(
                interested_user.id,
                event_1.id,
                :interested,
              )

              event_1.reload

              # we stop processing jobs immediately at this point to prevent infinite loop
              # as future event ended job would finish now, trigger next recurrence, and other job...
              Jobs.run_later!
            end

            context "when the event ends" do
              it "sets the next dates" do
                event_1.update_with_params!(original_ends_at: Time.now)

                expect(event_1.starts_at.to_s).to eq("2020-08-19 13:32:00 UTC")
                expect(event_1.ends_at.to_s).to eq("2020-08-19 16:32:00 UTC")
              end

              it "removes status from non going invitees" do
                going_invitee =
                  event_1.invitees.find_by(status: DiscoursePostEvent::Invitee.statuses[:going])
                interested_invitee =
                  event_1.invitees.find_by(
                    status: DiscoursePostEvent::Invitee.statuses[:interested],
                  )

                event_1.update_with_params!(original_ends_at: Time.now)

                expect(going_invitee.reload.status).to eq(
                  DiscoursePostEvent::Invitee.statuses[:going],
                )
                expect(interested_invitee.reload.status).to eq(nil)
              end

              # that will be handled by new job, uncomment when finished
              it "doesn’t resend event creation notification to invitees" do
                expect { event_1.update_with_params!(original_ends_at: Time.now) }.not_to change {
                  going_user.notifications.count
                }
              end
            end
          end

          context "when updating raw_invitees" do
            let(:lurker_1) { Fabricate(:user) }
            let(:group_1) { Fabricate(:group) }

            it "doesn’t accept usernames" do
              event_1.update_with_params!(raw_invitees: [lurker_1.username])
              expect(event_1.raw_invitees).to eq(["trust_level_0"])
            end

            it "doesn’t accept another group than trust_level_0" do
              event_1.update_with_params!(raw_invitees: [group_1.name])
              expect(event_1.raw_invitees).to eq(["trust_level_0"])
            end
          end

          context "when updating status to private" do
            it "changes the status and force invitees" do
              expect(event_1.raw_invitees).to eq(["trust_level_0"])
              expect(event_1.status).to eq(DiscoursePostEvent::Event.statuses[:public])

              event_1.update_with_params!(status: DiscoursePostEvent::Event.statuses[:private])

              expect(event_1.raw_invitees).to eq([])
              expect(event_1.status).to eq(DiscoursePostEvent::Event.statuses[:private])
            end
          end
        end
      end
    end

    context "when a post is created" do
      context "when the post contains one valid event" do
        context "when the acting user is admin" do
          it "creates the post event" do
            start = Time.now.utc.iso8601(3)

            post =
              PostCreator.create!(
                user,
                title: "Sell a boat party",
                raw: "[event start=\"#{start}\"]\n[/event]",
              )

            expect(post.reload.persisted?).to eq(true)
            expect(post.event.persisted?).to eq(true)
            expect(post.event.original_starts_at).to eq_time(Time.parse(start))
          end

          it "works with name attribute" do
            post = create_post_with_event(user, 'name="foo bar"').reload
            expect(post.event.name).to eq("foo bar")
          end

          it "works with url attribute" do
            url = "https://www.discourse.org"

            post = create_post_with_event(user, "url=\"#{url}\"").reload
            expect(post.event.url).to eq(url)
          end

          it "works with status attribute" do
            post = create_post_with_event(user, 'status="private"').reload
            expect(post.event.status).to eq(DiscoursePostEvent::Event.statuses[:private])
          end

          it "works with allowedGroups attribute" do
            Fabricate(:group, name: "euro")
            Fabricate(:group, name: "america")

            post = create_post_with_event(user, 'allowedGroups="euro"').reload
            expect(post.event.raw_invitees).to eq([])

            post = create_post_with_event(user, 'status="public" allowedGroups="euro"').reload
            expect(post.event.raw_invitees).to eq(%w[trust_level_0])

            post = create_post_with_event(user, 'status="standalone" allowedGroups="euro"').reload
            expect(post.event.raw_invitees).to eq([])

            post = create_post_with_event(user, 'status="private" allowedGroups="euro"').reload
            expect(post.event.raw_invitees).to eq(%w[euro])

            post =
              create_post_with_event(user, 'status="private" allowedGroups="euro,america"').reload
            expect(post.event.raw_invitees).to match_array(%w[euro america])

            post = create_post_with_event(user, 'status="private"').reload
            expect(post.event.raw_invitees).to eq([])

            post = create_post_with_event(user, 'status="private"').reload
            expect(post.event.raw_invitees).to eq([])
          end

          it "works with localised automatic group names" do
            I18n.locale = SiteSetting.default_locale = "fr"

            group = Group.find(Group::AUTO_GROUPS[:trust_level_0])
            group.update!(name: I18n.t("groups.default_names.trust_level_0"))

            post =
              create_post_with_event(user, 'status="public" allowedGroups="trust_level_0"').reload
            expect(post.event.raw_invitees).to eq(%w[trust_level_0])
          end

          it "works with reminders attribute" do
            post = create_post_with_event(user).reload
            expect(post.event.reminders).to eq(nil)

            post =
              create_post_with_event(
                user,
                'reminders="notification.1.hours,bumpTopic.-3.days"',
              ).reload
            expect(post.event.reminders).to eq("notification.1.hours,bumpTopic.-3.days")
          end

          context "with custom fields" do
            before { SiteSetting.discourse_post_event_allowed_custom_fields = "foo-bar|bar" }

            it "works with allowed custom fields" do
              post = create_post_with_event(user, 'fooBar="1"').reload
              expect(post.event.custom_fields["foo-bar"]).to eq("1")

              post = create_post_with_event(user, 'bar="2"').reload
              expect(post.event.custom_fields["bar"]).to eq("2")
            end

            it "doesn’t work with not allowed custom fields" do
              post = create_post_with_event(user, 'baz="3"').reload
              expect(post.event.custom_fields["baz"]).to eq(nil)
            end
          end
        end

        context "when the acting user has rights to create events" do
          let(:user_with_rights) { Fabricate(:user, refresh_auto_groups: true) }
          let(:group) { Fabricate(:group, users: [user_with_rights]) }

          before { SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s }

          it "creates the post event" do
            start = Time.now.utc.iso8601(3)

            post =
              PostCreator.create!(
                user_with_rights,
                title: "Sell a boat party",
                raw: "[event start=\"#{start}\"]\n[/event]",
              )

            expect(post.reload.persisted?).to eq(true)
            expect(post.event.persisted?).to eq(true)
            expect(post.event.original_starts_at).to eq_time(Time.parse(start))
          end
        end

        context "when the acting user doesn’t have rights to create events" do
          let(:user_without_rights) { Fabricate(:user, refresh_auto_groups: true) }
          let(:group) { Fabricate(:group, users: [user]) }

          before { SiteSetting.discourse_post_event_allowed_on_groups = group.id.to_s }

          it "raises an error" do
            start = Time.now.utc.iso8601(3)

            expect do
              PostCreator.create!(
                user_without_rights,
                title: "Sell a boat party",
                raw: "[event start=\"#{start}\"]\n[/event]",
              )
            end.to(
              raise_error(ActiveRecord::RecordNotSaved).with_message(
                I18n.t(
                  "discourse_post_event.errors.models.event.acting_user_not_allowed_to_create_event",
                ),
              ),
            )
          end
        end
      end

      context "when the post contains one invalid event" do
        context "when start is invalid" do
          it "raises an error" do
            expect do
              PostCreator.create!(
                user,
                title: "Sell a boat party",
                raw: "[event start=\"x\"]\n[/event]",
              )
            end.to(
              raise_error(ActiveRecord::RecordNotSaved).with_message(
                I18n.t(
                  "discourse_post_event.errors.models.event.start_must_be_present_and_a_valid_date",
                ),
              ),
            )
          end
        end

        context "when recurrence is invalid" do
          it "raises an error" do
            expect { create_post_with_event(user, 'recurrence="foo"') }.to raise_error(
              I18n.t("discourse_post_event.errors.models.event.invalid_recurrence"),
            )
          end
        end

        context "when start is not provided or" do
          it "is not cooked" do
            post = PostCreator.create!(user, title: "Sell a boat party", raw: <<~TXT)
                [event end=\"1\"]
                [/event]
              TXT

            expect(!post.cooked.include?("discourse-post-event")).to be(true)
          end
        end

        context "when end is provided and is invalid" do
          it "raises an error" do
            expect do
              PostCreator.create!(
                user,
                title: "Sell a boat party",
                raw: "[event start=\"#{Time.now.utc.iso8601(3)}\" end=\"d\"]\n[/event]",
              )
            end.to(
              raise_error(ActiveRecord::RecordNotSaved).with_message(
                I18n.t("discourse_post_event.errors.models.event.end_must_be_a_valid_date"),
              ),
            )
          end
        end
      end

      context "when the post contains multiple events" do
        it "raises an error" do
          expect { PostCreator.create!(user, title: "Sell a boat party", raw: <<~TXT) }.to(
                [event start=\"#{Time.now.utc.iso8601(3)}\"]
                [/event]

                [event start=\"#{Time.now.utc.iso8601(3)}\"]
                [/event]
              TXT
            raise_error(ActiveRecord::RecordNotSaved).with_message(
              I18n.t("discourse_post_event.errors.models.event.only_one_event"),
            ),
          )
        end
      end
    end

    context "when a post with an event is destroyed" do
      it "sets deleted_at on the post_event" do
        expect(event_1.deleted_at).to be_nil

        PostDestroyer.new(user, event_1.post).destroy
        event_1.reload

        expect(event_1.deleted_at).to eq_time(Time.now)
      end
    end

    context "when a post with an event is recovered" do
      it "nullifies deleted_at on the post_event" do
        PostDestroyer.new(user, event_1.post).destroy

        expect(event_1.reload.deleted_at).to eq_time(Time.now)

        PostDestroyer.new(user, Post.with_deleted.find(event_1.id)).recover

        expect(event_1.reload.deleted_at).to be_nil
      end
    end
  end

  context "with a private event" do
    before { freeze_time Time.utc(2020, 8, 12, 16, 32) }

    let(:invitee_1) { Fabricate(:user) }
    let(:invitee_2) { Fabricate(:user) }
    let(:group_1) do
      Fabricate(:group).tap do |g|
        g.add(invitee_1)
        g.add(invitee_2)
        g.save!
      end
    end
    let(:post_1) { Fabricate(:post) }
    let(:event_1) do
      Fabricate(
        :event,
        post: post_1,
        status: DiscoursePostEvent::Event.statuses[:private],
        raw_invitees: [group_1.name],
        original_starts_at: 3.hours.ago,
        original_ends_at: nil,
      )
    end

    context "with an event with recurrence" do
      let(:event_1) do
        Fabricate(
          :event,
          post: post_1,
          status: DiscoursePostEvent::Event.statuses[:private],
          raw_invitees: [group_1.name],
          recurrence: "FREQ=WEEKLY;BYDAY=MO",
          original_starts_at: 2.hours.from_now,
          original_ends_at: nil,
        )
      end

      before do
        # we stop processing jobs immediately at this point to prevent infinite loop
        # as future event ended job would finish now, trigger next recurrence, and other job...
        Jobs.run_later!
      end

      context "when updating the end" do
        it "resends event creation notification to invitees and suggested users" do
          expect { event_1.update_with_params!(original_ends_at: 3.hours.from_now) }.to change {
            invitee_1.notifications.count + invitee_2.notifications.count
          }.by(2)
        end
      end
    end

    context "when updating raw_invitees" do
      let(:lurker_1) { Fabricate(:user) }
      let(:group_2) { Fabricate(:group) }

      it "doesn’t accept usernames" do
        expect { event_1.update_with_params!(raw_invitees: [lurker_1.username]) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end

      it "accepts another group than trust_level_0" do
        event_1.update_with_params!(raw_invitees: [group_2.name])
        expect(event_1.raw_invitees).to eq([group_2.name])
      end
    end

    context "when updating status to public" do
      it "changes the status and force invitees" do
        expect(event_1.raw_invitees).to eq([group_1.name])
        expect(event_1.status).to eq(DiscoursePostEvent::Event.statuses[:private])

        event_1.update_with_params!(status: DiscoursePostEvent::Event.statuses[:public])

        expect(event_1.raw_invitees).to eq(["trust_level_0"])
        expect(event_1.status).to eq(DiscoursePostEvent::Event.statuses[:public])
      end
    end

    it "rejects private groups in allowedGroups" do
      moderator = Fabricate(:user, moderator: true)
      private_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])

      expect {
        create_post_with_event(moderator, "allowedGroups='#{private_group.name}'")
      }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it "rejects non-existent groups in allowedGroups" do
      moderator = Fabricate(:user, moderator: true)

      expect {
        create_post_with_event(moderator, "allowedGroups='non-existent_group_name'")
      }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it "rejects public groups with private members in allowedGroups" do
      moderator = Fabricate(:user, moderator: true)
      public_group_with_private_members =
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:public],
          members_visibility_level: Group.visibility_levels[:owners],
        )

      expect {
        create_post_with_event(
          moderator,
          "allowedGroups='#{public_group_with_private_members.name}'",
        )
      }.to raise_error(ActiveRecord::RecordNotSaved)
    end
  end

  context "with holiday events" do
    let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

    before do
      SiteSetting.holiday_calendar_topic_id = calendar_post.topic_id
      SiteSetting.enable_user_status = true
    end

    context "when adding a post with an event" do
      it "sets holiday user status" do
        freeze_time Time.utc(2018, 6, 5, 10, 30)

        raw = 'Vacation [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
        post = create_post(raw: raw, topic: calendar_post.topic)

        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
        expect(status.emoji).to eq(SiteSetting.holiday_status_emoji)
        expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))
      end

      it "doesn't set holiday user status if user already has custom user status" do
        freeze_time Time.utc(2018, 6, 5, 10, 30)

        # user sets a custom status
        custom_status = { description: "I am working on holiday", emoji: "construction_worker_man" }
        user.set_status!(custom_status[:description], custom_status[:emoji])

        raw = 'Vacation [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
        post = create_post(raw: raw, topic: calendar_post.topic, user: user)

        # a holiday status wasn't set:
        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(custom_status[:description])
        expect(status.emoji).to eq(custom_status[:emoji])
      end

      context "when using multiple calendars" do
        let(:regular_calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

        it "doesn't set holiday user status for a non-holiday calendar" do
          freeze_time Time.utc(2018, 6, 5, 10, 30)

          raw = 'Meeting [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
          post = create_post(raw: raw, topic: regular_calendar_post.topic, user: user)

          # a holiday status wasn't set:
          expect(post.user.user_status).to be_nil
        end
      end

      context "when custom emoji is set" do
        custom_emoji = "palm_tree"

        before { SiteSetting.holiday_status_emoji = custom_emoji }

        it "sets holiday user status with custom emoji" do
          freeze_time Time.utc(2018, 6, 5, 10, 30)

          raw =
            'Vacation [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
          post = create_post(raw: raw, topic: calendar_post.topic)

          status = post.user.user_status
          expect(status).to be_present
          expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
          expect(status.emoji).to eq(custom_emoji)
          expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))
        end
      end

      context "when custom emoji is blank" do
        before { SiteSetting.holiday_status_emoji = "" }

        it "sets holiday user status with the default emoji" do
          freeze_time Time.utc(2018, 6, 5, 10, 30)

          raw =
            'Vacation [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
          post = create_post(raw: raw, topic: calendar_post.topic)

          status = post.user.user_status
          expect(status).to be_present
          expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
          expect(status.emoji).to eq("date")
          expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))
        end
      end
    end

    context "when updating event dates" do
      it "sets holiday user status" do
        freeze_time Time.utc(2018, 6, 5, 10, 30)
        today = "2018-06-05"
        tomorrow = "2018-06-06"

        raw = "Vacation [date='#{tomorrow}']"
        post = create_post(raw: raw, topic: calendar_post.topic)
        expect(post.user.user_status).to be_blank

        PostRevisor.new(post).revise!(post.user, { raw: "Vacation [date='#{today}']" })
        post.reload

        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
        expect(status.emoji).to eq(SiteSetting.holiday_status_emoji)
        expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 0, 0))
      end

      it "doesn't set holiday user status if user already has custom user status" do
        freeze_time Time.utc(2018, 6, 5, 10, 30)
        today = "2018-06-05"
        tomorrow = "2018-06-06"

        raw = "Vacation [date='#{tomorrow}']"
        post = create_post(raw: raw, topic: calendar_post.topic)
        expect(post.user.user_status).to be_blank

        # user sets a custom status
        custom_status = { description: "I am working on holiday", emoji: "construction_worker_man" }
        post.user.set_status!(custom_status[:description], custom_status[:emoji])

        PostRevisor.new(post).revise!(post.user, { raw: "Vacation [date='#{today}']" })
        post.reload

        # a holiday status wasn't set:
        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(custom_status[:description])
        expect(status.emoji).to eq(custom_status[:emoji])
      end
    end

    context "when deleting a post with an event" do
      it "clears user status that was previously set by the calendar plugin" do
        freeze_time Time.utc(2018, 6, 5, 10, 30)

        raw = 'Vacation [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
        post = create_post(raw: raw, topic: calendar_post.topic)
        DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

        # the job has set the holiday status:
        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
        expect(status.emoji).to eq(SiteSetting.holiday_status_emoji)
        expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))

        # after destroying the post the holiday status disappears:
        PostDestroyer.new(user, post).destroy
        post.user.reload

        expect(post.user.user_status).to be_nil
      end

      it "doesn't clear user status that wasn't set by the calendar plugin" do
        freeze_time Time.utc(2018, 6, 5, 10, 30)

        raw = 'Vacation [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
        post = create_post(raw: raw, topic: calendar_post.topic)
        DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

        # the job has set the holiday status:
        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
        expect(status.emoji).to eq(SiteSetting.holiday_status_emoji)
        expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))

        # user sets a custom status
        custom_status = { description: "I am working on holiday", emoji: "construction_worker_man" }
        post.user.set_status!(custom_status[:description], custom_status[:emoji])

        # the status that was set by user doesn't disappear after destroying the post:
        PostDestroyer.new(user, post).destroy
        post.user.reload

        status = post.user.user_status
        expect(status).to be_present
        expect(status.description).to eq(custom_status[:description])
        expect(status.emoji).to eq(custom_status[:emoji])
      end
    end
  end

  describe "timezone handling" do
    before { freeze_time Time.utc(2022, 7, 24, 13, 00) }

    it "stores the correct information in the database" do
      expected_datetime = ActiveSupport::TimeZone["Australia/Sydney"].parse("2022-07-24 14:01")

      post =
        PostCreator.create!(
          user,
          title: "Beach party",
          raw: "[event start='2022-07-24 14:01' timezone='Australia/Sydney']\n[/event]",
        ).reload

      expect(post.event.timezone).to eq("Australia/Sydney")
      expect(post.event.original_starts_at).to eq_time(expected_datetime)
      expect(post.event.starts_at).to eq_time(expected_datetime)
      expect(post.event.event_dates.first.starts_at).to eq_time(expected_datetime)
    end

    it "raises an error for invalid timezone" do
      expect {
        PostCreator.create!(
          user,
          title: "Beach party",
          raw: "[event start='2022-07-24 14:01' timezone='Westeros/Winterfell']\n[/event]",
        )
      }.to raise_error(I18n.t("discourse_post_event.errors.models.event.invalid_timezone"))
    end

    it "handles simple weekly recurrence correctly" do
      # Friday in Aus, Thursday in UTC
      expected_original_datetime =
        ActiveSupport::TimeZone["Australia/Sydney"].parse("2022-07-01 09:01")
      expected_next_datetime = ActiveSupport::TimeZone["Australia/Sydney"].parse("2022-07-29 09:01")

      post =
        PostCreator.create!(
          user,
          title: "Friday beach party",
          raw:
            "[event start='2022-07-01 09:01' end='2022-07-01 10:01' timezone='Australia/Sydney' recurrence='every_week']\n[/event]",
        ).reload

      expect(post.event.timezone).to eq("Australia/Sydney")
      expect(post.event.original_starts_at).to eq_time(expected_original_datetime)
      expect(post.event.starts_at).to eq_time(expected_next_datetime)
    end

    it "handles recurrence across daylight saving" do
      # DST starts on 27th March. Original datetime is before that. Expecting
      # local time to be correct after the DST change
      expected_original_datetime = ActiveSupport::TimeZone["Europe/Paris"].parse("2022-03-20 09:01")
      expected_next_datetime = ActiveSupport::TimeZone["Europe/Paris"].parse("2022-07-25 09:01")

      post =
        PostCreator.create!(
          user,
          title: "Friday beach party",
          raw:
            "[event start='2022-03-20 09:01' end='2022-03-20 10:01' timezone='Europe/Paris' recurrence='every_day']\n[/event]",
        ).reload

      expect(post.event.timezone).to eq("Europe/Paris")
      expect(post.event.original_starts_at).to eq_time(expected_original_datetime)
      expect(post.event.starts_at).to eq_time(expected_next_datetime)
    end
  end
end
