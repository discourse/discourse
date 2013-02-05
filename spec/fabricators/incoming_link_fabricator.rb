Fabricator(:incoming_link) do
  url 'http://localhost:3000/t/pinball/76/6'
  referer 'https://twitter.com/evil_trout'
end

Fabricator(:incoming_link_not_topic, from: :incoming_link) do
  url 'http://localhost:3000/made-up-url'
  referer 'https://twitter.com/evil_trout'
end
