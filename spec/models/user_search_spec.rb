require 'rails_helper'

describe UserSearch do
  it 'allows for correct underscore searching' do
    Fabricate(:user, username: 'Under_Score')
    Fabricate(:user, username: 'undertaker')

    expect(search_for_user("under_sc").length).to eq(1)
    expect(search_for_user("under_").length).to eq(1)
  end

  it 'allows filtering by group' do
    group = Fabricate(:group)
    sam = Fabricate(:user, username: 'sam')
    _samantha = Fabricate(:user, username: 'samantha')
    group.add(sam)

    results = search_for_user("sam", group: group)
    expect(results.count).to eq(1)
  end
end
