Fabricator(:incoming_link) do
  user
  post
  ip_address { sequence(:ip_address) { |n| "123.#{(n * 3) % 255}.#{(n * 2) % 255}.#{n % 255}" } }
end
