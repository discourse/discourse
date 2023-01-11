# frozen_string_literal: true

task "chat:doc" do
  ["plugins/chat/assets/javascripts/discourse/services/chat-api.js"].each do |file|
    origin = File.join(Rails.root, file)
    filename = File.basename(file, ".*")
    destination = File.join(Rails.root, "plugins/chat/docs/#{filename}.md")
    config = File.join(Rails.root, ".jsdoc")

    `jsdoc2md -c #{config} #{origin} > #{destination}`
  end
end
