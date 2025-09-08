# frozen_string_literal: true

# got to ensure evals are here
# rubocop:disable Discourse/Plugins/NamespaceConstants
EVAL_PATH = File.join(__dir__, "../cases")
# rubocop:enable Discourse/Plugins/NamespaceConstants
#
if !Dir.exist?(EVAL_PATH)
  puts "Evals are missing, cloning from discourse/discourse-ai-evals"

  success =
    system("git clone git@github.com:discourse/discourse-ai-evals.git '#{EVAL_PATH}' 2>/dev/null")

  # Fall back to HTTPS if SSH fails
  if !success
    puts "SSH clone failed, falling back to HTTPS..."
    success = system("git clone https://github.com/discourse/discourse-ai-evals.git '#{EVAL_PATH}'")
  end

  if success
    puts "Successfully cloned evals repository"
  else
    abort "Failed to clone evals repository"
  end
end

discourse_path = ENV["DISCOURSE_PATH"] || File.expand_path(File.join(__dir__, "../../../.."))
# rubocop:disable Discourse/NoChdir
Dir.chdir(discourse_path)
# rubocop:enable Discourse/NoChdir

require "#{discourse_path}/config/environment"

ENV["DISCOURSE_AI_NO_DEBUG"] = "1"
module DiscourseAi::Evals
end
