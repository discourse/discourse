# frozen_string_literal: true

describe DiscoursePostEvent::EventSerializer do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }
  fab!(:post) { Fabricate(:post, topic: topic) }

  context "with a private event" do
    fab!(:private_event) do
      Fabricate(:event, post: post, status: DiscoursePostEvent::Event.statuses[:private])
    end

    fab!(:invitee_1) { Fabricate(:user) }
    fab!(:invitee_2) { Fabricate(:user) }
    fab!(:group_1) do
      Fabricate(:group).tap do |g|
        g.add(invitee_1)
        g.add(invitee_2)
        g.save!
      end
    end

    context "when some invited users have not rsvp-ed yet" do
      before do
        private_event.update_with_params!(raw_invitees: [group_1.name])
        DiscoursePostEvent::Invitee.create_attendance!(invitee_1.id, private_event.id, :going)
        private_event.reload
      end

      it "returns the correct stats" do
        json = DiscoursePostEvent::EventSerializer.new(private_event, scope: Guardian.new).as_json
        expect(json[:event][:stats]).to eq(going: 1, interested: 0, invited: 2, not_going: 0)
      end
    end
  end

  context "with a public event" do
    fab!(:event) { Fabricate(:event, post: post) }

    it "returns the event category's id" do
      json = DiscoursePostEvent::EventSerializer.new(event, scope: Guardian.new).as_json
      expect(json[:event][:category_id]).to eq(category.id)
    end
  end
end
