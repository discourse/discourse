# frozen_string_literal: true

task "run_automation" => :environment do
  script_methods = DiscourseAutomation::Scriptable.all

  scripts = []

  DiscourseAutomation::Automation.find_each do |automation|
    script_methods.each do |name|
      type = name.to_s.gsub("script_", "")

      next if type != automation.script

      scriptable = automation.scriptable
      scriptable.public_send(name)
      scripts << scriptable.script.call
    end
  end
end
