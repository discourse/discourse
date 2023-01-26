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

  require "yard"
  YARD::Templates::Engine.register_template_path(
    File.join(Rails.root, "documentation", "yard-custom-template"),
  )
  files = %w[plugins/chat/app/services/base.rb plugins/chat/app/services/trash_channel.rb]
  `bundle exec yardoc -p documentation/yard-custom-template -t default -r plugins/chat/README.md --output-dir documentation/chat/backend #{files.join(" ")}`
end
