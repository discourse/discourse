# frozen_string_literal: true

task "chat:doc" do
  unless system("command -v jsdoc2md >/dev/null;")
    abort "jsdoc2md is not installed. https://github.com/jsdoc2md/jsdoc-to-markdown"
  end

  ["plugins/chat/assets/javascripts/discourse/services/chat-api.js"].each do |file|
    origin = File.join(Rails.root, file)
    filename = File.basename(file, ".*")
    destination = File.join(Rails.root, "plugins/chat/docs/#{filename}.md")

    require "tempfile"
    config = Tempfile.new("jsdoc-config")
    config.write('{"source": { "excludePattern": "" } }')
    config.rewind

    # jsdoc doesn't accept paths starting with _ (which is the case on github runners)
    # so we need to alter the default config
    `jsdoc2md -c #{config.path} #{origin} > #{destination}`

    config.close
    config.unlink
  end
end
