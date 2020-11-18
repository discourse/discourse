# frozen_string_literal: true

class Plugin::Instance
  def add_automation_script(name, &block)
    reloadable_patch do
      DiscourseAutomation::Script.add_script(name, &block)
    end
  end
end
