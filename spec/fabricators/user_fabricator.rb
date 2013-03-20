Fabricator(:user) do
  name 'Bruce Wayne'
  username { sequence(:username) { |i| "bruce#{i}" } }
  email { sequence(:email) { |i| "bruce#{i}@wayne.com" } }
  password 'myawesomepassword'
  trust_level TrustLevel.levels[:basic]
  bio_raw "I'm batman!"
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

Fabricator(:moderator, from: :user) do
  name 'A. Moderator'
  username 'moderator'
  email 'moderator@discourse.org'
  moderator true
end

Fabricator(:admin, from: :user) do
  name 'Anne Admin'
  username 'anne'
  email 'anne@discourse.org'
  admin true
end

Fabricator(:another_admin, from: :user) do
  name 'Anne Admin the 2nd'
  username 'anne2'
  email 'anne2@discourse.org'
  admin true
end

