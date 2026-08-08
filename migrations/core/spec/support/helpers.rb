# frozen_string_literal: true

def reset_memoization(instance, *variables)
  variables.each do |var|
    instance.remove_instance_variable(var) if instance.instance_variable_defined?(var)
  end
end

def fixture_root
  @fixture_root ||= File.join(Migrations.root_path, "spec", "support", "fixtures")
end

# Tears down a constant a test defined on `Object`. `Module#remove_const` is
# private by design, so this helper is the one sanctioned spot that reaches for
# it via `send`.
def remove_test_const(name)
  Object.send(:remove_const, name) # rubocop:disable Style/Send
end
