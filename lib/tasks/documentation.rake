# frozen_string_literal: true

task "documentation" do
  generate_chat_documentation
end

def generate_chat_documentation
  destination = File.join(Rails.root, "documentation/chat/frontend/")
  config = File.join(Rails.root, ".jsdoc")

  files = %w[
    plugins/chat/assets/javascripts/discourse/lib/collection.js
    plugins/chat/assets/javascripts/discourse/services/chat-api.js
  ]
  `yarn --silent jsdoc -c #{config} #{files.join(" ")} -d #{destination}`

  YARD::Templates::Engine.register_template_path(
    File.join(Rails.root, "documentation", "yard-custom-template"),
  )
  `bundle exec yardoc -p documentation/yard-custom-template -t default -r plugins/chat/README.md --output-dir documentation/chat/backend plugins/chat/app/services/chat_channel_destroyer.rb`
end
