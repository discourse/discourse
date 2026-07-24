# frozen_string_literal: true

RSpec.describe(DiscoursePostEvent::ListInvitees) do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:post_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin, :admin)
    fab!(:topic) { Fabricate(:topic, user: admin) }
    fab!(:post) { Fabricate(:post, user: admin, topic: topic) }
    fab!(:event) { Fabricate(:event, post: post) }

    fab!(:francis) { Fabricate(:user, username: "Francis") }
    fab!(:francisco) { Fabricate(:user, username: "Francisco") }
    fab!(:frank) { Fabricate(:user, username: "Frank") }
    fab!(:franchesca) { Fabricate(:user, username: "Franchesca") }
    fab!(:franny) { Fabricate(:user, username: "Franny") }

    before do
      Jobs.run_immediately!
      SiteSetting.calendar_enabled = true
      SiteSetting.discourse_post_event_enabled = true

      event.create_invitees(
        [
          { user_id: francis.id, status: DiscoursePostEvent::Invitee.statuses[:going] },
          { user_id: francisco.id, status: DiscoursePostEvent::Invitee.statuses[:interested] },
          { user_id: frank.id, status: DiscoursePostEvent::Invitee.statuses[:not_going] },
          { user_id: franchesca.id, status: DiscoursePostEvent::Invitee.statuses[:going] },
        ],
      )
    end

    let(:params) { { post_id: event.id } }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when the contract is invalid" do
      let(:params) { { post_id: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when the type is not a valid status" do
      let(:params) { { post_id: event.id, type: "nonexistent" } }

      it { is_expected.to fail_a_contract }
    end

    context "when the event does not exist" do
      let(:params) { { post_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:event) }
    end

    context "when the user cannot see the event" do
      fab!(:group)
      fab!(:private_category) { Fabricate(:private_category, group:) }
      fab!(:private_topic) { Fabricate(:topic, user: admin, category: private_category) }
      fab!(:private_post) { Fabricate(:post, user: admin, topic: private_topic) }
      fab!(:private_event) { Fabricate(:event, post: private_post) }
      fab!(:outsider, :user)

      let(:params) { { post_id: private_event.id } }
      let(:dependencies) { { guardian: outsider.guardian } }

      it { is_expected.to fail_a_policy(:can_see_event) }
    end

    context "when no filter is given" do
      it { is_expected.to run_successfully }

      it "returns every invitee and no suggestions" do
        expect(result.invitees.size).to eq(4)
        expect(result.suggested_users).to be_blank
      end
    end

    context "when filtering invitees by name" do
      let(:params) { { post_id: event.id, filter: "Franc" } }

      it "only returns invitees whose username matches" do
        expect(result.invitees.map { |i| i.user.username }).to contain_exactly(
          "Francis",
          "Francisco",
          "Franchesca",
        )
      end
    end

    context "when filtering invitees by type" do
      let(:params) { { post_id: event.id, type: "going" } }

      it "only returns invitees with that status" do
        expect(result.invitees.map { |i| i.user.username }).to contain_exactly(
          "Francis",
          "Franchesca",
        )
      end
    end

    context "when filtering invitees by name and type" do
      let(:params) { { post_id: event.id, filter: "Franc", type: "going" } }

      it "returns invitees matching both" do
        expect(result.invitees.map { |i| i.user.username }).to contain_exactly(
          "Francis",
          "Franchesca",
        )
      end
    end

    context "when the user can act on the event" do
      let(:params) { { post_id: event.id, filter: "Fran", type: "going" } }

      it "suggests matching users who are not yet invited" do
        expect(result.suggested_users.map(&:username)).to contain_exactly(
          "Francisco",
          "Frank",
          "Franny",
        )
      end

      context "when the filter is blank" do
        let(:params) { { post_id: event.id, filter: "", type: "going" } }

        it "returns no suggestions" do
          expect(result.suggested_users).to be_blank
        end
      end
    end

    context "when the user cannot act on the event" do
      fab!(:lurker, :user)
      let(:dependencies) { { guardian: lurker.guardian } }
      let(:params) { { post_id: event.id, filter: "Fran" } }

      it "returns no suggestions" do
        expect(result.suggested_users).to be_blank
      end
    end

    context "when the filter contains SQL LIKE wildcards" do
      let(:params) { { post_id: event.id, filter: "fr_nk" } }

      it "treats the wildcards literally instead of matching everything" do
        expect(result.invitees).to be_empty
        expect(result.suggested_users).to be_empty
      end
    end
  end
end
