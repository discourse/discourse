# frozen_string_literal: true

class Plugin::Instance
  def add_automation_scriptable(name, &block)
    reloadable_patch do
      DiscourseAutomation::Scriptable.add(name, &block)
    end
  end
end
