Fabricator(:post_detail) do
  post
  key { sequence(:key) { |i| "key#{i}" } }
  value "test value"
end
