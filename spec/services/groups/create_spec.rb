# frozen_string_literal: true
RSpec.describe Groups::Create do
  describe Groups::Create::Contract, type: :model do
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

    describe "custom_fields_allowed_keys" do
      it "accepts custom_fields when no editable group custom fields are registered" do
        contract =
          described_class.new(
            name: "builders",
            custom_fields: {
              arbitrary_key: "value",
            },
            options: nil,
          )
        expect(contract).to be_valid
      end

      context "when some group custom fields are registered" do
        before { Plugin::Instance.new.register_editable_group_custom_field(:test) }

        after { DiscoursePluginRegistry.reset! }

        it "rejects custom_fields with disallowed keys when some keys are registered" do
          contract =
            described_class.new(
              name: "builders",
              custom_fields: {
                disallowed_key: "x",
              },
              options: nil,
            )
          expect(contract).not_to be_valid
          expect(contract.errors[:custom_fields].first).to include("disallowed key: disallowed_key")
        end

        it "accepts custom_fields with allowed keys" do
          contract =
            described_class.new(name: "builders", custom_fields: { test: "value" }, options: nil)
          expect(contract).to be_valid
        end

        it "accepts blank custom_fields" do
          contract = described_class.new(name: "builders", custom_fields: {}, options: nil)
          expect(contract).to be_valid
        end
      end
    end
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies, options:) }

    fab!(:admin)
    fab!(:moderator)
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

    context "when the user is not an admin" do
      let(:guardian) { member_1.guardian }

      it { is_expected.to fail_a_policy(:can_create_group) }
    end

    context "when invalid visibility_level is provided" do
      let(:params) { { name: "builders", visibility_level: 999 } }

      it { is_expected.to fail_a_contract }
    end

    context "when invalid members_visibility_level is provided" do
      let(:params) { { name: "builders", members_visibility_level: 999 } }

      it { is_expected.to fail_a_contract }
    end

    context "when guardian is a moderator without moderators_manage_groups" do
      let(:guardian) { moderator.guardian }
      let(:params) { { name: "builders", title: "Builders" } }

      before { SiteSetting.moderators_manage_groups = false }

      it { is_expected.to fail_a_policy(:can_create_group) }
    end

    context "when guardian cannot associate groups" do
      fab!(:associated_group_1, :associated_group)
      fab!(:associated_group_2, :associated_group)

      it "does not assign associated_group_ids to the group" do
        allow(AssociatedGroup).to receive(:has_provider?).and_return(false)

        result =
          described_class.call(
            params: {
              name: "builders",
              title: "Builders",
              associated_group_ids: [associated_group_1.id, associated_group_2.id],
            },
            guardian: admin.guardian,
          )

        expect(result).to run_successfully
        expect(result.group.group_associated_groups).to be_empty
      end
    end

    context "when everything is ok" do
      it { is_expected.to run_successfully }

      it "creates a new group" do
        result

        created_group = Group.last
        expect(created_group).to have_attributes(name: "builders", title: "Builders")
        expect(created_group.group_users.where(user: admin, owner: true)).to be_present
        expect(created_group.group_users.where(user: member_1, owner: false)).to be_present
        expect(created_group.group_users.where(user: member_2, owner: false)).to be_present
      end

      it "logs group history for both the group owner and the group members" do
        expect { result }.to change(GroupHistory, :count).by(4)

        created_group = result.group
        histories = GroupHistory.where(group: created_group)
        expect(histories.count).to eq(4)
        expect(
          histories.where(action: GroupHistory.actions[:make_user_group_owner]).pluck(
            :acting_user_id,
          ),
        ).to contain_exactly(admin.id)
        expect(
          histories.where(action: GroupHistory.actions[:make_user_group_owner]).pluck(
            :target_user_id,
          ),
        ).to contain_exactly(admin.id)
        expect(
          histories.where(action: GroupHistory.actions[:add_user_to_group]).pluck(:target_user_id),
        ).to contain_exactly(member_1.id, member_2.id, admin.id)
      end

      context "when dynamic attributes are provided" do
        let(:options) { { dynamic_attributes: { allow_unknown_sender_topic_replies: true } } }
        let(:created_group) { Group.last }

        before { Plugin::Instance.new.register_group_param :allow_unknown_sender_topic_replies }

        after { DiscoursePluginRegistry.reset! }

        it "creates a new group with the dynamic attributes" do
          result
          expect(created_group.allow_unknown_sender_topic_replies).to eq(true)
        end
      end

      context "when allow_membership_requests is false" do
        let(:params) do
          {
            name: "builders",
            allow_membership_requests: false,
            membership_request_template: "Please let me in",
          }
        end

        it "sets membership_request_template to nil on the group" do
          result

          expect(Group.last.membership_request_template).to be_nil
        end
      end

      context "when allow_membership_requests is true" do
        let(:params) do
          {
            name: "builders",
            allow_membership_requests: true,
            membership_request_template: "Please let me in",
          }
        end

        it "persists membership_request_template on the group" do
          expect(result.group.membership_request_template).to eq("Please let me in")
        end
      end

      context "when no owners or members are provided" do
        let(:params) { { name: "empty_group", title: "Empty" } }

        it "creates a group with no group_users" do
          created_group = result.group
          expect(created_group).to have_attributes(name: "empty_group", title: "Empty")
          expect(created_group.group_users).to be_empty
        end

        it "does not log any group history for the group" do
          expect { result }.not_to change(GroupHistory, :count)
        end
      end
    end

    context "when the user is a moderator with moderators_manage_groups" do
      let(:guardian) { moderator.guardian }
      let(:params) { { name: "builders", title: "Builders" } }

      before { SiteSetting.moderators_manage_groups = true }

      it "passes the policy and creates the group" do
        expect(result).to run_successfully
        expect(Group.last).to have_attributes(name: "builders", title: "Builders")
      end
    end
  end
end
