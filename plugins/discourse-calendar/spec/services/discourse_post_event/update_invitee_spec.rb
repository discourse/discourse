# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscoursePostEvent::UpdateAttendance do
  subject(:result) { described_class.call(guardian: guardian, params: params) }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  let(:user) { Fabricate(:user) }
  let(:guardian) { Guardian.new(user) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post) { Fabricate(:post, user: user, topic: topic) }
  let(:event) { Fabricate(:event, post: post) }
  let!(:invitee) do
    event.create_invitees([{ user_id: user.id, status: :going }])
    event.invitees.find_by(user_id: user.id)
  end
  let(:params) { { invitee_id: invitee.id, event_id: event.id, status: "going" } }

  describe ".call" do
    context "when mandatory parameters are missing" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when status is invalid" do
      let(:params) { { invitee_id: invitee.id, event_id: event.id, status: "invalid_status" } }

      it { is_expected.to fail_a_contract }
    end

    context "when invitee is not found" do
      let(:params) { { invitee_id: 999_999, event_id: event.id, status: "going" } }

      it { is_expected.to fail_to_find_a_model(:invitee) }
    end

    context "when invitee belongs to different event" do
      let(:other_event) { Fabricate(:event) }
      let(:params) { { invitee_id: invitee.id, event_id: other_event.id, status: "going" } }

      it { is_expected.to fail_to_find_a_model(:invitee) }
    end

    context "when user cannot act on invitee" do
      let(:other_user) { Fabricate(:user) }
      let(:guardian) { Guardian.new(other_user) }

      it { is_expected.to fail_a_policy(:can_act_on_invitee) }
    end

    context "when user can act on invitee" do
      context "when updating to going status and event is at capacity" do
        before do
          event.update!(max_attendees: 1)
          # Create another invitee who is already going
          other_user = Fabricate(:user)
          event.create_invitees(
            [{ user_id: other_user.id, status: DiscoursePostEvent::Invitee.statuses[:going] }],
          )
          # Set current invitee to not_going initially
          invitee.update!(status: DiscoursePostEvent::Invitee.statuses[:not_going])
        end

        let(:params) { { invitee_id: invitee.id, event_id: event.id, status: "going" } }

        it { is_expected.to fail_to_find_a_model(:updated_invitee) }
      end

      context "when update is successful" do
        it { is_expected.to run_successfully }

        it "updates the invitee status" do
          expect { result }.to change { invitee.reload.status }.to(
            DiscoursePostEvent::Invitee.statuses[:going],
          )
        end

        it "returns the updated invitee" do
          expect(result.updated_invitee).to eq(invitee)
        end

        it "triggers discourse event" do
          events = DiscourseEvent.track_events { result }
          expect(events).to include(
            event_name: :discourse_calendar_post_event_invitee_status_changed,
            params: [invitee.reload],
          )
        end

        context "when changing from going to not_going" do
          before { invitee.update!(status: DiscoursePostEvent::Invitee.statuses[:going]) }

          let(:params) { { invitee_id: invitee.id, event_id: event.id, status: "not_going" } }

          it "updates the status successfully" do
            expect { result }.to change { invitee.reload.status }.to(
              DiscoursePostEvent::Invitee.statuses[:not_going],
            )
          end
        end

        context "when changing from not_going to interested" do
          before { invitee.update!(status: DiscoursePostEvent::Invitee.statuses[:not_going]) }

          let(:params) { { invitee_id: invitee.id, event_id: event.id, status: "interested" } }

          it "updates the status successfully" do
            expect { result }.to change { invitee.reload.status }.to(
              DiscoursePostEvent::Invitee.statuses[:interested],
            )
          end
        end
      end

      context "when user is admin acting on behalf of another user" do
        let(:admin) { Fabricate(:admin) }
        let(:guardian) { Guardian.new(admin) }
        let(:other_user) { Fabricate(:user) }
        let!(:invitee) do
          event.create_invitees([{ user_id: other_user.id, status: :going }])
          event.invitees.find_by(user_id: other_user.id)
        end

        it { is_expected.to run_successfully }

        it "updates the invitee status" do
          expect { result }.to change { invitee.reload.status }.to(
            DiscoursePostEvent::Invitee.statuses[:going],
          )
        end
      end
    end
  end
end
