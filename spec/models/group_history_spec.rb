require 'rails_helper'

RSpec.describe GroupHistory do
  let(:group_history) { Fabricate(:group_history) }

  let(:other_group_history) do
    Fabricate(:group_history,
      action: GroupHistory.actions[:remove_user_from_group],
      group: group_history.group
    )
  end

  describe '.with_filters' do
    it 'should return the right records' do
      expect(described_class.with_filters(group_history.group))
        .to eq([group_history])
    end

    it 'should filter by action correctly' do
      other_group_history

      expect(described_class.with_filters(
        group_history.group,
        action: GroupHistory.actions[3]
      )).to eq([other_group_history])
    end

    it 'should filter by subject correctly' do
      other_group_history.update_attributes!(subject: "test")

      expect(described_class.with_filters(
        group_history.group,
        subject: 'test'
      )).to eq([other_group_history])
    end

    it 'should filter by multiple filters correctly' do
      group_history.update_attributes!(action: GroupHistory.actions[:remove_user_from_group])
      other_group_history.update_attributes!(subject: "test")

      expect(described_class.with_filters(group_history.group,
        action: GroupHistory.actions[3], subject: 'test'
      )).to eq([other_group_history])
    end

    it 'should filter by target_user and acting_user correctly' do
      group_history
      other_group_history

      group_history_3 = Fabricate(:group_history,
        group: group_history.group,
        acting_user: other_group_history.acting_user,
        target_user: other_group_history.target_user,
        action: GroupHistory.actions[:remove_user_as_group_owner]
      )

      expect(described_class.with_filters(
        group_history.group,
        target_user: other_group_history.target_user.username
      ).sort).to eq([other_group_history, group_history_3])

      expect(described_class.with_filters(
        group_history.group,
        acting_user: group_history.acting_user.username
      )).to eq([group_history])

      expect(described_class.with_filters(
        group_history.group,
        acting_user: group_history_3.acting_user.username, target_user: other_group_history.target_user.username
      ).sort).to eq([other_group_history, group_history_3])
    end
  end
end
