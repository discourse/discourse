# frozen_string_literal: true

Fabricator(:user_stat) {}

Fabricator(:user, class_name: :user) do
  transient refresh_auto_groups: false
  transient trust_level: nil
  transient search_index: false

  name "Bruce Wayne"
  username { sequence(:username) { |i| "bruce#{i}" } }
  email { sequence(:email) { |i| "bruce#{i}@wayne.com" } }
  password "myawesomepassword"
  ip_address { sequence(:ip_address) { |i| "99.232.23.#{i % 254}" } }
  active true

  after_build { |user, transients| user.trust_level = transients[:trust_level] || TrustLevel[1] }

  after_create do |user, transients|
    if transients[:refresh_auto_groups] || transients[:trust_level]
      Group.user_trust_level_change!(user.id, user.trust_level)
    end
    SearchIndexer.disable if transients[:search_index]
  end

  before_create { |user, transients| SearchIndexer.enable if transients[:search_index] }
end

Fabricator(:user_with_secondary_email, from: :user) do
  after_create { |user| Fabricate(:secondary_email, user: user) }
end

Fabricator(:coding_horror, from: :user) do
  name "Coding Horror"
  username "CodingHorror"
  email "jeff@somewhere.com"
  password "mymoreawesomepassword"
end

Fabricator(:evil_trout, from: :user) do
  name "Evil Trout"
  username "eviltrout"
  email "eviltrout@somewhere.com"
  password "imafish123"
end

Fabricator(:walter_white, from: :user) do
  name "Walter White"
  username "heisenberg"
  email "wwhite@bluemeth.com"
  password "letscook123"
end

Fabricator(:inactive_user, from: :user) do
  name "Inactive User"
  username "inactive_user"
  email "inactive@idontexist.com"
  password "qwerqwer123"
  active false
end

Fabricator(:moderator, from: :user) do
  name { sequence(:name) { |i| "A#{i} Moderator" } }
  username { sequence(:username) { |i| "moderator#{i}" } }
  email { sequence(:email) { |i| "moderator#{i}@discourse.org" } }
  moderator true

  after_create do |user|
    user.group_users << Fabricate(:group_user, user: user, group: Group[:moderators])
    user.group_users << Fabricate(:group_user, user: user, group: Group[:staff])
  end
end

Fabricator(:admin, from: :user) do
  name "Anne Admin"
  username { sequence(:username) { |i| "anne#{i}" } }
  email { sequence(:email) { |i| "anne#{i}@discourse.org" } }
  admin true
  trust_level TrustLevel[4]

  after_create do |user|
    user.group_users << Fabricate(:group_user, user: user, group: Group[:admins])
    user.group_users << Fabricate(:group_user, user: user, group: Group[:staff])
  end
end

Fabricator(:newuser, from: :user) do
  name "Newbie Newperson"
  username "newbie"
  email "newbie@new.com"
  trust_level TrustLevel[0]
end

Fabricator(:active_user, from: :user) do
  name "Luke Skywalker"
  username { sequence(:username) { |i| "luke#{i}" } }
  email { sequence(:email) { |i| "luke#{i}@skywalker.com" } }
  password "myawesomepassword"
  trust_level TrustLevel[1]

  after_create do |user|
    user.user_profile.bio_raw = "Don't ask me about my dad!"
    user.user_profile.save!
  end
end

Fabricator(:leader, from: :user) do
  name "Veteran McVeteranish"
  username { sequence(:username) { |i| "leader#{i}" } }
  email { sequence(:email) { |i| "leader#{i}@leaderfun.com" } }
  trust_level TrustLevel[3]
end

Fabricator(:trust_level_0, from: :user) { trust_level TrustLevel[0] }
Fabricator(:trust_level_1, from: :user) { trust_level TrustLevel[1] }
Fabricator(:trust_level_2, from: :user) { trust_level TrustLevel[2] }
Fabricator(:trust_level_3, from: :user) { trust_level TrustLevel[3] }

Fabricator(:trust_level_4, from: :user) do
  name "Leader McElderson"
  username { sequence(:username) { |i| "tl4#{i}" } }
  email { sequence(:email) { |i| "tl4#{i}@elderfun.com" } }
  trust_level TrustLevel[4]
end

Fabricator(:anonymous, from: :user) do
  name ""
  username { sequence(:username) { |i| "anonymous#{i}" } }
  email { sequence(:email) { |i| "anonymous#{i}@anonymous.com" } }
  trust_level TrustLevel[1]
  manual_locked_trust_level TrustLevel[1]

  after_create do
    # this is not "the perfect" fabricator in that user id -1 is system
    # but creating a proper account here is real slow and has a huge
    # impact on the test suite run time
    create_anonymous_user_master(master_user_id: -1, active: true)
  end
end

Fabricator(:staged, from: :user) { staged true }

Fabricator(:unicode_user, from: :user) { username { sequence(:username) { |i| "Löwe#{i}" } } }

Fabricator(:bot, from: :user) do
  id do
    min_id = User.minimum(:id)
    [(min_id || 0) - 1, -10].min
  end
end

Fabricator(:east_coast_user, from: :user) do
  email "eastcoast@tz.com"
  after_create do |user|
    user.user_option = UserOption.new(timezone: "Eastern Time (US & Canada)")
    user.save
  end
end
