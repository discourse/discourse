# frozen_string_literal: true

module DiscourseAutomation
  module PluginInstanceExtension
    def add_automation_scriptable(name, &block)
      reloadable_patch { DiscourseAutomation::Scriptable.add(name, &block) }
    end

    def add_automation_triggerable(name, &block)
      reloadable_patch { DiscourseAutomation::Triggerable.add(name, &block) }
    end

    def add_triggerable_to_scriptable(triggerable, scriptable)
      reloadable_patch do
        DiscourseAutomation::Scriptable.add_plugin_triggerable(triggerable, scriptable)
      end
    end
  end
end
