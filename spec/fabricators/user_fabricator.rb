Fabricator(:user_stat) do
end

Fabricator(:user) do
  name 'Bruce Wayne'
  username { sequence(:username) { |i| "bruce#{i}" } }
  email { sequence(:email) { |i| "bruce#{i}@wayne.com" } }
  password 'myawesomepassword'
  trust_level TrustLevel[1]
  ip_address { sequence(:ip_address) { |i| "99.232.23.#{i%254}"} }
  active true
end

Fabricator(:coding_horror, from: :user) do
  name 'Coding Horror'
  username 'CodingHorror'
  email 'jeff@somewhere.com'
  password 'mymoreawesomepassword'
end

Fabricator(:evil_trout, from: :user) do
  name 'Evil Trout'
  username 'eviltrout'
  email 'eviltrout@somewhere.com'
  password 'imafish'
end

Fabricator(:walter_white, from: :user) do
  name 'Walter White'
  username 'heisenberg'
  email 'wwhite@bluemeth.com'
  password 'letscook'
end

Fabricator(:inactive_user, from: :user) do
  name 'Inactive User'
  username 'inactive_user'
  email 'inactive@idontexist.com'
  active false
end

Fabricator(:moderator, from: :user) do
  name { sequence(:name) {|i| "A#{i} Moderator"} }
  username { sequence(:username) {|i| "moderator#{i}"} }
  email { sequence(:email) {|i| "moderator#{i}@discourse.org"} }
  moderator true
end

Fabricator(:admin, from: :user) do
  name 'Anne Admin'
  username { sequence(:username) {|i| "anne#{i}"} }
  email { sequence(:email) {|i| "anne#{i}@discourse.org"} }
  admin true
end

Fabricator(:newuser, from: :user) do
  name 'Newbie Newperson'
  username 'newbie'
  email 'newbie@new.com'
  trust_level TrustLevel[0]
end

Fabricator(:active_user, from: :user) do
  name 'Luke Skywalker'
  username { sequence(:username) { |i| "luke#{i}" } }
  email { sequence(:email) { |i| "luke#{i}@skywalker.com" } }
  password 'myawesomepassword'
  trust_level TrustLevel[1]

  after_create do |user|
    user.user_profile.bio_raw = "Don't ask me about my dad!"
    user.user_profile.save!
  end
end

Fabricator(:leader, from: :user) do
  name 'Veteran McVeteranish'
  username { sequence(:username) { |i| "leader#{i}" } }
  email { sequence(:email) { |i| "leader#{i}@leaderfun.com" } }
  trust_level TrustLevel[3]
end

Fabricator(:trust_level_4, from: :user) do
  name 'Leader McElderson'
  username { sequence(:username) { |i| "tl4#{i}" } }
  email { sequence(:email) { |i| "tl4#{i}@elderfun.com" } }
  trust_level TrustLevel[4]
end

Fabricator(:anonymous, from: :user) do
  name ''
  username { sequence(:username) { |i| "anonymous#{i}" } }
  email { sequence(:email) { |i| "anonymous#{i}@anonymous.com" } }
  trust_level TrustLevel[1]
  trust_level_locked true

  after_create do |user|
    user.custom_fields["master_id"] = 1
    user.save!
  end
end
