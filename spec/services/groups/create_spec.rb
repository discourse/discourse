# frozen_string_literal: true

RSpec.describe Groups::Create do
  describe Groups::Create::Contract, type: :model do
    subject(:contract) { described_class.new(name: "builders", **attributes) }

    let(:attributes) { {} }

    it { is_expected.to validate_presence_of :name }
    it do
      is_expected.to validate_inclusion_of(:mentionable_level).in_array(Group::ALIAS_LEVELS.values)
    end
    it do
      is_expected.to validate_inclusion_of(:messageable_level).in_array(Group::ALIAS_LEVELS.values)
    end
    it do
      is_expected.to validate_inclusion_of(:visibility_level).in_array(
        Group.visibility_levels.values,
      )
    end
    it do
      is_expected.to validate_inclusion_of(:members_visibility_level).in_array(
        Group.visibility_levels.values,
      )
    end
    it do
      is_expected.to validate_inclusion_of(:default_notification_level).in_array(
        GroupUser.notification_levels.values,
      )
    end

    context "when no editable group custom fields are registered" do
      it { is_expected.to allow_value({}).for(:custom_fields) }
      it { is_expected.to allow_value({ arbitrary_key: "value" }).for(:custom_fields) }
    end

    context "when editable group custom fields are registered" do
      before { Plugin::Instance.new.register_editable_group_custom_field(:test) }

      after { DiscoursePluginRegistry.reset! }

      it { is_expected.to allow_value({}).for(:custom_fields) }
      it { is_expected.to allow_value({ test: "value" }).for(:custom_fields) }
      it { is_expected.not_to allow_value({ disallowed_key: "x" }).for(:custom_fields) }
    end

    describe "#membership_request_template" do
      let(:attributes) { { membership_request_template: "Please let me in" } }

      before { contract.valid? }

      context "when allow_membership_requests is false" do
        it "is nilified after validation" do
          expect(contract.membership_request_template).to be_nil
        end
      end

      context "when allow_membership_requests is true" do
        let(:attributes) do
          { membership_request_template: "Please let me in", allow_membership_requests: true }
        end

        it "is preserved after validation" do
          expect(contract.membership_request_template).to eq("Please let me in")
        end
      end
    end

    describe "#owner_ids" do
      fab!(:user_1, :user)
      fab!(:user_2, :user)

      context "when owner_usernames is blank" do
        it { expect(contract.owner_ids).to be_empty }
      end

      context "when owner_usernames is present" do
        let(:attributes) { { owner_usernames: [user_1.username, user_2.username] } }

        it "returns user IDs for the given usernames" do
          expect(contract.owner_ids).to contain_exactly(user_1.id, user_2.id)
        end
      end
    end

    describe "#user_ids" do
      fab!(:owner, :user)
      fab!(:member_1, :user)
      fab!(:member_2, :user)

      context "when usernames is blank" do
        it { expect(contract.user_ids).to be_empty }
      end

      context "when usernames is present" do
        let(:attributes) { { usernames: [member_1.username, member_2.username] } }

        it "returns user IDs for the given usernames" do
          expect(contract.user_ids).to contain_exactly(member_1.id, member_2.id)
        end
      end

      context "when usernames includes an owner" do
        let(:attributes) do
          { owner_usernames: [owner.username], usernames: [owner.username, member_1.username] }
        end

        it "excludes owner IDs" do
          expect(contract.user_ids).to contain_exactly(member_1.id)
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies, options:) }

    fab!(:admin)
    fab!(:member_1, :user)
    fab!(:member_2, :user)

    let(:dependencies) { { guardian: } }
    let(:options) { {} }
    let(:guardian) { admin.guardian }
    let(:params) do
      {
        name: "builders",
        title: "Builders",
        usernames: [member_1.username, member_2.username].join(","),
        owner_usernames: [admin.username].join(","),
      }
    end

    context "when user cannot create groups" do
      let(:guardian) { member_1.guardian }

      it { is_expected.to fail_a_policy(:can_create_group) }
    end

    context "when data is invalid" do
      let(:params) { { name: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when everything's ok" do
      let(:group) { result.group }

      it { is_expected.to run_successfully }

      it "creates a group with the specified attributes" do
        expect(group).to have_attributes(name: "builders", title: "Builders")
      end

      it "assigns owners" do
        expect(group.group_users.where(owner: true).map(&:user)).to contain_exactly(admin)
      end

      it "assigns members" do
        expect(group.group_users.where(owner: false).map(&:user)).to contain_exactly(
          member_1,
          member_2,
        )
      end

      it "logs group history" do
        expect { result }.to change { GroupHistory.count }.by(4)
      end

      context "when guardian can associate groups" do
        fab!(:associated_group_1, :associated_group)
        fab!(:associated_group_2, :associated_group)

        before do
          allow(guardian).to receive(:can_associate_groups?).and_return(true)
          params[:associated_group_ids] = [associated_group_1.id, associated_group_2.id]
        end

        it { is_expected.to run_successfully }

        it "assigns associated groups" do
          expect(group.associated_groups).to contain_exactly(associated_group_1, associated_group_2)
        end
      end

      context "when guardian cannot associate groups" do
        fab!(:associated_group_1, :associated_group)

        before do
          allow(guardian).to receive(:can_associate_groups?).and_return(false)
          params[:associated_group_ids] = [associated_group_1.id]
        end

        it { is_expected.to run_successfully }

        it "does not assign associated groups" do
          expect(group.associated_groups).to be_empty
        end
      end

      context "with dynamic attributes" do
        let(:options) { { dynamic_attributes: { allow_unknown_sender_topic_replies: true } } }

        before { Plugin::Instance.new.register_group_param(:allow_unknown_sender_topic_replies) }

        after { DiscoursePluginRegistry.reset! }

        it { is_expected.to run_successfully }

        it "applies the dynamic attributes" do
          expect(group.allow_unknown_sender_topic_replies).to eq(true)
        end
      end

      context "with membership_request_template" do
        before do
          params.merge!(
            allow_membership_requests: true,
            membership_request_template: "Please let me in",
          )
        end

        it { is_expected.to run_successfully }

        it "applies the value from the contract" do
          expect(group.membership_request_template).to eq("Please let me in")
        end
      end

      context "without owners or members" do
        let(:params) { { name: "empty_group", title: "Empty" } }

        it { is_expected.to run_successfully }

        it "creates a group with no group_users" do
          expect(group.group_users).to be_empty
        end

        it "does not log any group history" do
          expect { result }.not_to change { GroupHistory.count }
        end
      end
    end
  end
end
