# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Jobs::FixUserUsernamesAndGroupsNamesClash do
  it 'update usernames of users that clashes with a group name' do
    user = Fabricate(:user)
    Fabricate(:user, username: 'test1')
    group = Fabricate(:group, name: 'test')
    user.update_columns(username: 'test', username_lower: 'test')

    Jobs::FixUserUsernamesAndGroupsNamesClash.new.execute({})

    expect(user.reload.username).to eq('test2')
    expect(group.reload.name).to eq('test')
  end
end
