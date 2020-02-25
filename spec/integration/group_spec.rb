# frozen_string_literal: true

require 'rails_helper'

describe Group do
  let(:group) do
    Fabricate(
      :group,
      visibility_level: Group.visibility_levels[:public],
      mentionable_level: Group::ALIAS_LEVELS[:nobody],
      users: [ Fabricate(:user) ]
    )
  end

  let(:post) { Fabricate(:post, raw: "mention @#{group.name}") }

  before do
    Jobs.run_immediately!
  end

  it 'users can mention public groups, but does not create a notification' do
    expect { post }.not_to change { Notification.where(notification_type: Notification.types[:group_mentioned]).count }
    expect(post.cooked).to include("<a class=\"mention-group\" href=\"/groups/#{group.name}\">@#{group.name}</a>")
  end
end
