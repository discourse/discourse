# frozen_string_literal: true

task "chat:doc" do
  destination = File.join(Rails.root, "plugins/chat/docs/FRONTEND.md")
  config = File.join(Rails.root, ".jsdoc")

  files = %w[
    plugins/chat/assets/javascripts/discourse/lib/collection.js
    plugins/chat/assets/javascripts/discourse/services/chat-api.js
  ]

  `yarn --silent jsdoc2md --separators -c #{config} -f #{files.join(" ")} > #{destination}`
end
