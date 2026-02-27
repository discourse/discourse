# frozen_string_literal: true

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

        it "returns 400 when filtering by an invalid type" do
          get "/discourse-post-event/events/#{post_event_1.id}/invitees.json",
              params: {
                type: "nonexistent",
              }
          expect(response.status).to eq(400)
        end
      end
    end

    describe "#create" do
      let(:event) { Fabricate(:event, post: post_1) }

      it "creates an invitee" do
        post "/discourse-post-event/events/#{event.id}/invitees.json",
             params: {
               invitee: {
                 status: "going",
               },
             }

        expect(response.status).to eq(200)
        expect(Invitee).to exist(user_id: user.id, status: Invitee.statuses[:going])
      end

      it "allows staff to invite another user" do
        other_user = Fabricate(:user)

        post "/discourse-post-event/events/#{event.id}/invitees.json",
             params: {
               invitee: {
                 status: "interested",
                 user_id: other_user.id,
               },
             }

        expect(response.status).to eq(200)
        expect(Invitee).to exist(user_id: other_user.id, status: Invitee.statuses[:interested])
      end

      it "returns 403 when non-staff tries to invite themselves to a private event" do
        private_event = Fabricate(:event, post: post_1, status: "private")
        other_user = Fabricate(:user)
        sign_in(other_user)

        expect do
          post "/discourse-post-event/events/#{private_event.id}/invitees.json",
               params: {
                 invitee: {
                   status: "going",
                 },
               }
        end.not_to change { Invitee.count }

        expect(response.status).to eq(403)
      end

      context "when event is at max capacity" do
        fab!(:post_2) { create_post(user: Fabricate(:admin), category: Fabricate(:category)) }
        fab!(:user_a, :user)
        fab!(:user_b, :user)
        fab!(:full_event) do
          pe = Fabricate(:event, post: post_2, max_attendees: 1)
          pe.create_invitees([{ user_id: user_a.id, status: Invitee.statuses[:going] }])
          pe
        end

        it "returns 422 when trying to join as going" do
          sign_in(user_b)

          post "/discourse-post-event/events/#{full_event.id}/invitees.json",
               params: {
                 invitee: {
                   status: "going",
                 },
               }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"].join).to include("full")
        end

        it "allows interested when full" do
          sign_in(user_b)

          post "/discourse-post-event/events/#{full_event.id}/invitees.json",
               params: {
                 invitee: {
                   status: "interested",
                 },
               }

          expect(response.status).to eq(200)
        end
      end
    end

    describe "#update" do
      let(:invitee_user) { Fabricate(:user) }
      let(:event) do
        pe = Fabricate(:event, post: post_1)
        pe.create_invitees([{ user_id: invitee_user.id, status: Invitee.statuses[:going] }])
        pe
      end
      let(:invitee) { event.invitees.first }

      it "updates the invitee status" do
        put "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json",
            params: {
              invitee: {
                status: "interested",
              },
            }

        expect(response.status).to eq(200)
        expect(invitee.reload.status).to eq(Invitee.statuses[:interested])
      end

      it "returns 404 when invitee does not exist" do
        put "/discourse-post-event/events/#{event.id}/invitees/999999.json",
            params: {
              invitee: {
                status: "interested",
              },
            }

        expect(response.status).to eq(404)
      end

      it "returns 403 when user cannot act on invitee" do
        lurker = Fabricate(:user)
        sign_in(lurker)

        put "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json",
            params: {
              invitee: {
                status: "interested",
              },
            }

        expect(response.status).to eq(403)
      end

      context "when event is at max capacity" do
        fab!(:post_2) { create_post(user: Fabricate(:admin), category: Fabricate(:category)) }
        fab!(:user_a, :user)
        fab!(:user_b, :user)
        fab!(:full_event) do
          pe = Fabricate(:event, post: post_2, max_attendees: 1)
          pe.create_invitees([{ user_id: user_a.id, status: Invitee.statuses[:going] }])
          pe
        end
        fab!(:interested_invitee) do
          Fabricate(
            :invitee,
            post_id: post_2.id,
            user_id: user_b.id,
            status: Invitee.statuses[:interested],
          )
        end

        it "returns 422 when trying to change to going" do
          sign_in(user_b)

          put "/discourse-post-event/events/#{full_event.id}/invitees/#{interested_invitee.id}.json",
              params: {
                invitee: {
                  status: "going",
                },
              }

          expect(response.status).to eq(422)
          expect(response.parsed_body["errors"].join).to include("full")
        end

        it "allows changing to interested" do
          sign_in(user_b)

          put "/discourse-post-event/events/#{full_event.id}/invitees/#{interested_invitee.id}.json",
              params: {
                invitee: {
                  status: "interested",
                },
              }

          expect(response.status).to eq(200)
        end
      end
    end

    describe "#destroy" do
      let(:invitee_user) { Fabricate(:user) }
      let(:event) do
        pe = Fabricate(:event, post: post_1)
        pe.create_invitees([{ user_id: invitee_user.id, status: Invitee.statuses[:going] }])
        pe
      end
      let(:invitee) { event.invitees.first }

      it "destroys the invitee as staff" do
        delete "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json"

        expect(response.status).to eq(200)
        expect(Invitee.exists?(invitee.id)).to eq(false)
      end

      it "destroys the invitee as the invitee owner" do
        sign_in(invitee_user)

        delete "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json"

        expect(response.status).to eq(200)
        expect(Invitee.exists?(invitee.id)).to eq(false)
      end

      it "returns 403 when user cannot act on invitee" do
        lurker = Fabricate(:user)
        sign_in(lurker)

        delete "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json"

        expect(response.status).to eq(403)
        expect(Invitee.exists?(invitee.id)).to eq(true)
      end

      it "returns 404 when invitee does not exist" do
        delete "/discourse-post-event/events/#{event.id}/invitees/999999.json"

        expect(response.status).to eq(404)
      end
    end
  end

  describe "anonymous access to InviteesController" do
    before do
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true
    end

    fab!(:admin_user) { Fabricate(:user, admin: true) }
    fab!(:topic) { Fabricate(:topic, user: admin_user) }
    fab!(:post_1) { Fabricate(:post, user: admin_user, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post_1) }
    fab!(:invitee_user, :user)
    fab!(:invitee) do
      DiscoursePostEvent::Invitee.create!(
        post_id: post_1.id,
        user_id: invitee_user.id,
        status: DiscoursePostEvent::Invitee.statuses[:going],
      )
    end

    it "requires login for create" do
      post "/discourse-post-event/events/#{event.id}/invitees.json",
           params: {
             invitee: {
               status: "going",
             },
           }
      expect(response.status).to eq(403)
    end

    it "requires login for update" do
      put "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json",
          params: {
            invitee: {
              status: "interested",
            },
          }
      expect(response.status).to eq(403)
    end

    it "requires login for destroy" do
      delete "/discourse-post-event/events/#{event.id}/invitees/#{invitee.id}.json"
      expect(response.status).to eq(403)
    end
  end
end
