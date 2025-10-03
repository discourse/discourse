# frozen_string_literal: true

describe DiscoursePostEvent::EventFinder do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:user)

  subject(:finder) { DiscoursePostEvent::EventFinder }

  before do
    Jobs.run_immediately!
    SiteSetting.discourse_post_event_enabled = true
    Group.refresh_automatic_groups!
  end

  describe "by attending user" do
    fab!(:attending_user) { Fabricate(:user) }
    fab!(:public_event) { Fabricate(:event, status: DiscoursePostEvent::Event.statuses[:public]) }
    fab!(:private_event) { Fabricate(:event, status: DiscoursePostEvent::Event.statuses[:private]) }
    fab!(:another_event) { Fabricate(:event, status: DiscoursePostEvent::Event.statuses[:public]) }

    fab!(:attending_public_event) do
      DiscoursePostEvent::Invitee.create!(
        user: attending_user,
        event: public_event,
        status: DiscoursePostEvent::Invitee.statuses[:going],
      )
    end

    fab!(:attending_private_event) do
      DiscoursePostEvent::Invitee.create!(
        user: attending_user,
        event: private_event,
        status: DiscoursePostEvent::Invitee.statuses[:going],
      )
    end

    fab!(:not_attending_event) do
      DiscoursePostEvent::Invitee.create!(
        user: attending_user,
        event: another_event,
        status: DiscoursePostEvent::Invitee.statuses[:not_going],
      )
    end

    it "returns only events the user is attending" do
      expect(
        finder.search(current_user, { attending_user: attending_user.username }),
      ).to match_array([public_event])
    end

    it "includes private events for admin users" do
      current_user.update!(admin: true)
      expect(
        finder.search(current_user, { attending_user: attending_user.username }),
      ).to match_array([public_event, private_event])
    end

    it "includes private events if the searching user is also invited" do
      DiscoursePostEvent::Invitee.create!(
        user: current_user,
        event: private_event,
        status: DiscoursePostEvent::Invitee.statuses[:going],
      )

      expect(
        finder.search(current_user, { attending_user: attending_user.username }),
      ).to match_array([public_event, private_event])
    end
  end

  context "when the event is associated to a visible post" do
    let(:post1) do
      PostCreator.create!(
        user,
        title: "We should buy a boat",
        raw: "The boat market is quite active lately.",
      )
    end
    let!(:event) { Fabricate(:event, post: post1) }

    it "returns the event" do
      expect(finder.search(current_user)).to match_array([event])
    end
  end

  context "when the event is associated to a visible PM" do
    let(:post1) do
      PostCreator.create!(
        user,
        title: "We should buy a boat",
        raw: "The boat market is quite active lately.",
        archetype: Archetype.private_message,
        target_usernames: "#{current_user.username}",
      )
    end
    let!(:event) { Fabricate(:event, post: post1) }

    it "returns the event" do
      expect(finder.search(current_user)).to match_array([event])
    end
  end

  context "when the event is associated to a not visible PM" do
    let(:another_user) { Fabricate(:user) }
    let(:post1) do
      PostCreator.create!(
        user,
        title: "We should buy a boat",
        raw: "The boat market is quite active lately.",
        archetype: Archetype.private_message,
        target_usernames: "#{another_user.username}",
      )
    end
    let!(:event) { Fabricate(:event, post: post1) }

    it "doesn’t return the event" do
      expect(finder.search(current_user)).to match_array([])
    end
  end

  context "when events are filtered" do
    describe "by post_id" do
      let(:post1) do
        PostCreator.create!(
          user,
          title: "We should buy a boat",
          raw: "The boat market is quite active lately.",
        )
      end
      let(:post2) do
        PostCreator.create!(
          user,
          title: "We should buy another boat",
          raw: "The boat market is very active lately.",
        )
      end
      let!(:event1) { Fabricate(:event, post: post1) }
      let!(:event2) { Fabricate(:event, post: post2) }

      it "returns only the specified event" do
        expect(finder.search(current_user, { post_id: post2.id })).to match_array([event2])
      end
    end

    describe "with a limit parameter provided" do
      let!(:event1) { Fabricate(:event) }
      let!(:event2) { Fabricate(:event) }
      let!(:event3) { Fabricate(:event) }

      it "returns the correct number of events" do
        expect(finder.search(current_user, { limit: 2 })).to match_array([event1, event2])
      end
    end

    describe "with a before parameter provided" do
      let!(:event1) { Fabricate(:event, original_starts_at: 2.minutes.from_now) }
      let!(:event2) { Fabricate(:event, original_starts_at: 1.minute.from_now) }
      let!(:event3) { Fabricate(:event, original_starts_at: 2.hours.ago) }

      it "returns the events started before the provided value" do
        expect(finder.search(current_user, { before: event2.starts_at.to_s })).to match_array(
          [event3],
        )
      end
    end

    describe "recurring events date filtering" do
      let!(:recurring_event_june) do
        Fabricate(
          :event,
          original_starts_at: Time.parse("2024-06-15 10:00:00 UTC"),
          recurrence: "every_week",
          recurrence_until: Time.parse("2024-12-31 10:00:00 UTC"),
        )
      end

      let!(:recurring_event_endless) do
        Fabricate(
          :event,
          original_starts_at: Time.parse("2024-06-15 10:00:00 UTC"),
          recurrence: "every_week",
          recurrence_until: nil,
        )
      end

      let!(:non_recurring_event_august) do
        Fabricate(:event, original_starts_at: Time.parse("2024-08-15 10:00:00 UTC"))
      end

      describe "filtering for August events" do
        it "returns recurring events that start before August but recur until after August" do
          results =
            finder.search(
              current_user,
              {
                after: Time.parse("2024-08-01 00:00:00 UTC").to_s,
                before: Time.parse("2024-08-31 23:59:59 UTC").to_s,
              },
            )

          expect(results).to include(recurring_event_june)
          expect(results).to include(non_recurring_event_august)
          expect(results).to include(recurring_event_endless)
        end
      end

      describe "filtering for January next year events" do
        it "returns only endless recurring events and events that recur until after January" do
          results =
            finder.search(
              current_user,
              {
                after: Time.parse("2025-01-01 00:00:00 UTC").to_s,
                before: Time.parse("2025-01-31 23:59:59 UTC").to_s,
              },
            )

          expect(results).not_to include(recurring_event_june)
          expect(results).to include(recurring_event_endless)
          expect(results).not_to include(non_recurring_event_august)
        end
      end
    end

    describe "expired events" do
      let!(:expired_event) do
        Fabricate(:event, original_starts_at: 2.hours.ago, original_ends_at: 1.hour.ago)
      end

      let!(:current_event) do
        Fabricate(:event, original_starts_at: 1.hour.from_now, original_ends_at: 2.hours.from_now)
      end

      it "returns both expired and current events" do
        results = finder.search(current_user)
        expect(results).to include(expired_event)
        expect(results).to include(current_event)
      end
    end
  end
end
