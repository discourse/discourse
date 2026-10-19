# frozen_string_literal: true

module DiscourseEvents::Events
  describe "private event group invitees" do
    fab!(:event_owner, :admin)
    fab!(:invitee_user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:invited_group) do
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:owners],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    end
    fab!(:topic) { Fabricate(:topic, user: event_owner, category: Fabricate(:category)) }
    fab!(:post) { Fabricate(:post, user: event_owner, topic:) }
    fab!(:event) do
      Fabricate(
        :event,
        post:,
        status: DiscourseEvents::Events::Event.statuses[:private],
        raw_invitees: [invited_group.name],
      )
    end

    before do
      Jobs.run_immediately!
      SiteSetting.discourse_events_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      invited_group.add(invitee_user)
    end

    def create_invitee
      event.create_invitees(
        [{ user_id: invitee_user.id, status: DiscourseEvents::Events::Invitee.statuses[:going] }],
      )
      event.invitees.find_by(user_id: invitee_user.id)
    end

    it "removes invitee records when a user leaves an invited group" do
      invitee = create_invitee

      expect { invited_group.remove(invitee_user) }.to change {
        DiscourseEvents::Events::Invitee.unscoped.exists?(id: invitee.id)
      }.from(true).to(false)
    end

    it "blocks a stale invitee from private event details, attendance listings, and RSVP updates" do
      stale_invitee = create_invitee
      invited_group.remove(invitee_user)
      stale_invitee =
        DiscourseEvents::Events::Invitee
          .unscoped
          .find_or_create_by!(post_id: event.id, user_id: invitee_user.id) do |invitee|
            invitee.status = DiscourseEvents::Events::Invitee.statuses[:going]
          end

      sign_in(invitee_user)

      get "/discourse-post-event/events/#{event.id}.json"

      expect(response.status).to eq(200)
      event_json = response.parsed_body["event"]
      expect(event_json).not_to have_key("raw_invitees")
      expect(event_json).not_to have_key("sample_invitees")
      expect(event_json).not_to have_key("stats")
      expect(event_json["should_display_invitees"]).to eq(false)
      expect(event_json["can_update_attendance"]).to eq(false)
      expect(event_json["watching_invitee"]).to be_nil

      get "/discourse-post-event/events/#{event.id}/invitees.json"

      expect(response.status).to eq(403)
      expect(response.body).not_to include(invitee_user.username)

      get "/discourse-post-event/events.json",
          params: {
            attending_user: invitee_user.username,
            include_details: "true",
          }

      expect(response.status).to eq(200)
      expect(
        response.parsed_body["events"].map { |listed_event_json| listed_event_json["id"] },
      ).not_to include(event.id)

      put "/discourse-post-event/events/#{event.id}/invitees/#{stale_invitee.id}.json",
          params: {
            invitee: {
              status: "interested",
            },
          }

      expect(response.status).to eq(403)
      expect(response.parsed_body).not_to have_key("success")
      expect(stale_invitee.reload.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
    end
  end
end
