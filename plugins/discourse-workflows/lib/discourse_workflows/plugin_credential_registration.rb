# frozen_string_literal: true

class Plugin::Instance
  def register_discourse_workflows_credential_type(class_name)
    DiscoursePluginRegistry.register_discourse_workflows_credential_type(class_name, self)
  end
end
