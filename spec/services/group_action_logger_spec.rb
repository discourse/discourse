# frozen_string_literal: true

RSpec.describe GroupActionLogger do
  subject(:logger) { described_class.new(group_owner, group) }

  fab!(:group_owner, :user)
  fab!(:group)
  fab!(:user)

  before { group.add_owner(group_owner) }

  describe "#log_make_user_group_owner" do
    it "should create the right record" do
      logger.log_make_user_group_owner(user)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:make_user_group_owner])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.target_user).to eq(user)
    end
  end

  describe "#log_remove_user_as_group_owner" do
    it "should create the right record" do
      logger.log_remove_user_as_group_owner(user)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:remove_user_as_group_owner])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.target_user).to eq(user)
    end
  end

  describe "#log_add_user_to_group" do
    context "as a group owner" do
      it "should create the right record" do
        logger.log_add_user_to_group(user)

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
        expect(group_history.acting_user).to eq(group_owner)
        expect(group_history.target_user).to eq(user)
      end
    end

    context "as a normal user" do
      subject(:logger) { described_class.new(user, group) }

      before { group.update!(public_admission: true) }

      it "should create the right record" do
        logger.log_add_user_to_group(user)

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
        expect(group_history.acting_user).to eq(user)
        expect(group_history.target_user).to eq(user)
      end
    end
  end

  describe "#log_remove_user_from_group" do
    context "as group owner" do
      it "should create the right record" do
        logger.log_remove_user_from_group(user)

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:remove_user_from_group])
        expect(group_history.acting_user).to eq(group_owner)
        expect(group_history.target_user).to eq(user)
      end
    end

    context "as a normal user" do
      subject(:logger) { described_class.new(user, group) }

      before { group.update!(public_exit: true) }

      it "should create the right record" do
        logger.log_remove_user_from_group(user)

        group_history = GroupHistory.last

        expect(group_history.action).to eq(GroupHistory.actions[:remove_user_from_group])
        expect(group_history.acting_user).to eq(user)
        expect(group_history.target_user).to eq(user)
      end
    end
  end

  describe "#log_group_creation" do
    subject(:log_creation) { logger.log_group_creation }

    let(:owner_history) do
      GroupHistory.where(group:, action: GroupHistory.actions[:make_user_group_owner])
    end
    let(:member_history) do
      GroupHistory.where(group:, action: GroupHistory.actions[:add_user_to_group])
    end

    context "when group has only an owner" do
      it "logs make_user_group_owner for the owner" do
        expect { log_creation }.to change { owner_history.count }.by(1)
        expect(owner_history).to contain_exactly(
          an_object_having_attributes(acting_user: group_owner, target_user: group_owner),
        )
      end

      it "logs add_user_to_group for the owner" do
        expect { log_creation }.to change { member_history.count }.by(1)
        expect(member_history).to contain_exactly(
          an_object_having_attributes(acting_user: group_owner, target_user: group_owner),
        )
      end
    end

    context "when group has an owner and a member" do
      before { group.add(user) }

      it "logs make_user_group_owner only for the owner" do
        expect { log_creation }.to change { owner_history.count }.by(1)
        expect(owner_history).to contain_exactly(
          an_object_having_attributes(acting_user: group_owner, target_user: group_owner),
        )
      end

      it "logs add_user_to_group for both owner and member" do
        expect { log_creation }.to change { member_history.count }.by(2)
        expect(member_history).to contain_exactly(
          an_object_having_attributes(acting_user: group_owner, target_user: group_owner),
          an_object_having_attributes(acting_user: group_owner, target_user: user),
        )
      end
    end
  end

  describe "#log_change_group_settings" do
    it "should create the right record" do
      group.update!(public_admission: true, created_at: Time.zone.now)

      expect { logger.log_change_group_settings }.to change { GroupHistory.count }.by(1)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:change_group_setting])
      expect(group_history.acting_user).to eq(group_owner)
      expect(group_history.subject).to eq("public_admission")
      expect(group_history.prev_value).to eq("f")
      expect(group_history.new_value).to eq("t")
    end
  end
end
