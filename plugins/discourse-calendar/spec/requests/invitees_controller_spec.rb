# frozen_string_literal: true
require "rails_helper"

module DiscoursePostEvent
  describe InviteesController do
    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
      sign_in(user)
    end

    let(:user) { Fabricate(:user, admin: true) }
    let(:topic_1) { Fabricate(:topic, user: user) }
    let(:post_1) { Fabricate(:post, user: user, topic: topic_1) }

    describe "#index" do
      context "for a post in a private category" do
        let(:outside_user) { Fabricate(:user) }
        let(:in_group_user) { Fabricate(:user) }
        let(:group) { Fabricate(:group, users: [in_group_user]) }
        let(:private_category) { Fabricate(:private_category, group:) }
        let(:topic_1) { Fabricate(:topic, user: user, category: private_category) }
        let(:post_1) { Fabricate(:post, user: user, topic: topic_1) }
        let(:post_event_1) { Fabricate(:event, post: post_1) }

        it "forbids non group user from seeing the list of invitees" do
          sign_in(outside_user)

          get "/discourse-post-event/events/#{post_event_1.id}/invitees.json"

          expect(response.status).to eq(403)
        end

        it "allows group user to see the list of invitees" do
          sign_in(in_group_user)

          get "/discourse-post-event/events/#{post_event_1.id}/invitees.json"

          expect(response.status).to eq(200)
        end
      end

      context "when params are included" do
        let(:invitee1) { Fabricate(:user, username: "Francis", name: "Francis") }
        let(:invitee2) { Fabricate(:user, username: "Francisco", name: "Francisco") }
        let(:invitee3) { Fabricate(:user, username: "Frank", name: "Frank") }
        let(:invitee4) { Fabricate(:user, username: "Franchesca", name: "Franchesca") }
        let!(:random_user) { Fabricate(:user, username: "Franny") }
        let(:post_event_1) do
          pe = Fabricate(:event, post: post_1)
          pe.create_invitees(
            [
              { user_id: invitee1.id, status: Invitee.statuses[:going] },
              { user_id: invitee2.id, status: Invitee.statuses[:interested] },
              { user_id: invitee3.id, status: Invitee.statuses[:not_going] },
              { user_id: invitee4.id, status: Invitee.statuses[:going] },
            ],
          )
          pe
        end

        context "when user is allowed to act on post event" do
          it "returns users extra suggested users when filtering the invitees by name" do
            get "/discourse-post-event/events/#{post_event_1.id}/invitees.json",
                params: {
                  filter: "Fran",
                  type: "going",
                }

            suggested = response.parsed_body[:meta][:suggested_users].map { |u| u[:username] }.sort
            expect(suggested).to eq(%w[Francisco Frank Franny])

            get "/discourse-post-event/events/#{post_event_1.id}/invitees.json",
                params: {
                  filter: "",
                  type: "going",
                }

            suggested = response.parsed_body.dig(:meta, :suggested_users)
            expect(suggested).to be_blank
          end
        end

        it "returns the correct amount of users when filtering the invitees by name" do
          get "/discourse-post-event/events/#{post_event_1.id}/invitees.json",
              params: {
                filter: "Franc",
              }
          filteredInvitees = response.parsed_body["invitees"]
          expect(filteredInvitees.count).to eq(3)
        end

        it "returns the correct amount of users when filtering the invitees by type" do
          get "/discourse-post-event/events/#{post_event_1.id}/invitees.json",
              params: {
                type: "interested",
              }
          filteredInvitees = response.parsed_body["invitees"]
          expect(filteredInvitees.count).to eq(1)
        end

        it "returns the correct amount of users when filtering the invitees by name and type" do
          get "/discourse-post-event/events/#{post_event_1.id}/invitees.json",
              params: {
                filter: "Franc",
                type: "going",
              }
          filteredInvitees = response.parsed_body["invitees"]
          expect(filteredInvitees.count).to eq(2)
        end
      end
    end

    context "when a post event exists" do
      context "when an invitee exists" do
        let(:invitee1) { Fabricate(:user) }
        let(:post_event_2) do
          pe = Fabricate(:event, post: post_1)
          pe.create_invitees([{ user_id: invitee1.id, status: Invitee.statuses[:going] }])
          pe
        end

        describe "updating invitee" do
          it "updates its status" do
            invitee = post_event_2.invitees.first

            expect(invitee.status).to eq(0)

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json",
                params: {
                  invitee: {
                    status: "interested",
                  },
                }

            invitee.reload

            expect(invitee.status).to eq(1)
            expect(invitee.post_id).to eq(post_1.id)
          end
        end

        describe "destroying invitee" do
          context "when acting user can act on discourse event" do
            it "destroys the invitee" do
              invitee = post_event_2.invitees.first
              delete "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json"
              expect(Invitee.where(id: invitee.id).length).to eq(0)
              expect(response.status).to eq(200)
            end
          end

          context "when acting user can act on invitee" do
            before { sign_in(invitee1) }

            it "destroys the invitee" do
              invitee = post_event_2.invitees.first
              delete "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json"
              expect(Invitee.where(id: invitee.id).length).to eq(0)
              expect(response.status).to eq(200)
            end
          end

          context "when acting user can’t act on discourse event" do
            let(:lurker) { Fabricate(:user) }

            before { sign_in(lurker) }

            it "doesn’t destroy the invitee" do
              invitee = post_event_2.invitees.first
              delete "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json"
              expect(Invitee.where(id: invitee.id).length).to eq(1)
              expect(response.status).to eq(403)
            end
          end
        end

        context "when changing status" do
          it "sets tracking of the topic" do
            invitee = post_event_2.invitees.first

            expect(invitee.status).to eq(0)

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json",
                params: {
                  invitee: {
                    status: "interested",
                  },
                }

            tu = TopicUser.get(invitee.event.post.topic, invitee.user)
            expect(tu.notification_level).to eq(TopicUser.notification_levels[:tracking])

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json",
                params: {
                  invitee: {
                    status: "going",
                  },
                }

            tu = TopicUser.get(invitee.event.post.topic, invitee.user)
            expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])

            put "/discourse-post-event/events/#{post_event_2.id}/invitees/#{invitee.id}.json",
                params: {
                  invitee: {
                    status: "not_going",
                  },
                }

            tu = TopicUser.get(invitee.event.post.topic, invitee.user)
            expect(tu.notification_level).to eq(TopicUser.notification_levels[:regular])
          end
        end
      end

      context "when an invitee doesn’t exist" do
        let(:post_event_2) { Fabricate(:event, post: post_1) }

        it "creates an invitee" do
          post "/discourse-post-event/events/#{post_event_2.id}/invitees.json",
               params: {
                 invitee: {
                   status: "not_going",
                 },
               }

          expect(Invitee).to exist(user_id: user.id, status: 2)
        end

        it "sets tracking of the topic" do
          post "/discourse-post-event/events/#{post_event_2.id}/invitees.json",
               params: {
                 invitee: {
                   status: "going",
                 },
               }

          invitee = Invitee.find_by(user_id: user.id)

          tu = TopicUser.get(invitee.event.post.topic, user)
          expect(tu.notification_level).to eq(TopicUser.notification_levels[:watching])
        end

        context "when someone is trying to invite themselves to a private event (creepy)" do
          let(:post_event_2) { Fabricate(:event, post: post_1, status: "private") }
          let(:other_user) { Fabricate(:user, username: "creep") }

          before { sign_in(other_user) }

          it "does not create an invitee" do
            expect do
              post "/discourse-post-event/events/#{post_event_2.id}/invitees.json",
                   params: {
                     invitee: {
                       status: "going",
                     },
                   }
            end.not_to change { post_event_2.invitees.count }
          end
        end

        context "when the invitee is the event owner" do
          let(:post_event_2) { Fabricate(:event, post: post_1) }

          it "allows inviting other users" do
            user = Fabricate(:user)

            post "/discourse-post-event/events/#{post_event_2.id}/invitees.json",
                 params: {
                   invitee: {
                     status: "interested",
                     user_id: user.id,
                   },
                 }

            post_event_2.reload

            expect(post_event_2.invitees.length).to eq(1)
            invitee = post_event_2.invitees.first
            expect(invitee.status).to eq(1)
            expect(invitee.post_id).to eq(post_1.id)
            expect(invitee.user_id).to eq(user.id)
          end

          it "creates an invitee" do
            expect(post_event_2.invitees.length).to eq(0)

            post "/discourse-post-event/events/#{post_event_2.id}/invitees.json",
                 params: {
                   invitee: {
                     status: "interested",
                   },
                 }

            post_event_2.reload

            invitee = post_event_2.invitees.first
            expect(invitee.status).to eq(1)
            expect(invitee.post_id).to eq(post_1.id)
          end
        end
      end
    end
  end
end
