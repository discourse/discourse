# frozen_string_literal: true

require "fileutils"

task "documentation" do
  generate_chat_documentation
end

def generate_chat_documentation
  destination = File.join(Rails.root, "documentation/chat/frontend/")
  config = File.join(Rails.root, ".jsdoc")
  files = %w[
    plugins/chat/assets/javascripts/discourse/lib/collection.js
    plugins/chat/assets/javascripts/discourse/pre-initializers/chat-plugin-api.js
    plugins/chat/assets/javascripts/discourse/services/chat-api.js
  ]
  `yarn --silent jsdoc --readme plugins/chat/README.md -c #{config} #{files.join(" ")} -d #{destination}`

  # unecessary files
  %w[
    documentation/chat/frontend/scripts/prism.min.js
    documentation/chat/frontend/scripts/prism.js
    documentation/chat/frontend/styles/vendor/prism-default.css
    documentation/chat/frontend/styles/vendor/prism-okaidia.css
    documentation/chat/frontend/styles/vendor/prism-tomorrow-night.css
  ].each { |file| FileUtils.rm(file) }

  require "open3"
  require "yard"
  YARD::Templates::Engine.register_template_path(
    File.join(Rails.root, "documentation", "yard-custom-template"),
  )
  files = %w[
    plugins/chat/app/services/base.rb
    plugins/chat/app/services/update_user_last_read.rb
    plugins/chat/app/services/trash_channel.rb
    plugins/chat/app/services/update_channel.rb
    plugins/chat/app/services/update_channel_status.rb
  ]
  cmd =
    "bundle exec yardoc -p documentation/yard-custom-template -t default -r plugins/chat/README.md --output-dir documentation/chat/backend #{files.join(" ")}"
  Open3.popen3(cmd) { |_, stderr| puts stderr.read }
end
