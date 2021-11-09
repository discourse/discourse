# frozen_string_literal: true

class Plugin::Instance
  def add_automation_scriptable(name, &block)
    reloadable_patch do
      DiscourseAutomation::Scriptable.add(name, &block)
    end
  end

  def add_automation_triggerable(name, &block)
    reloadable_patch do
      DiscourseAutomation::Triggerable.add(name, &block)
    end
  end

  def add_triggerable_to_scriptable(triggerable, scriptable)
    reloadable_patch do
      DiscourseAutomation::Scriptable.add_plugin_triggerable(triggerable, scriptable)
    end
  end
end
