# frozen_string_literal: true

def reset_memoization(instance, *variables)
  variables.each do |var|
    instance.remove_instance_variable(var) if instance.instance_variable_defined?(var)
  end
end

def fixture_root
  @fixture_root ||= File.join(::Migrations.root_path, "spec", "support", "fixtures")
end
