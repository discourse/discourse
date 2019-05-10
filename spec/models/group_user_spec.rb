# frozen_string_literal: true

require 'rails_helper'

describe GroupUser do

  it 'correctly sets notification level' do
    moderator = Fabricate(:moderator)

    Group.refresh_automatic_groups!(:moderators)
    gu = GroupUser.find_by(user_id: moderator.id, group_id: Group::AUTO_GROUPS[:moderators])

    expect(gu.notification_level).to eq(NotificationLevels.all[:tracking])

    group = Group.create!(name: 'bob')
    group.add(moderator)
    group.save

    gu = GroupUser.find_by(user_id: moderator.id, group_id: group.id)
    expect(gu.notification_level).to eq(NotificationLevels.all[:watching])

    group.remove(moderator)
    group.save

    group.default_notification_level = 1
    group.save

    group.add(moderator)
    group.save

    gu = GroupUser.find_by(user_id: moderator.id, group_id: group.id)
    expect(gu.notification_level).to eq(NotificationLevels.all[:regular])
  end

end
