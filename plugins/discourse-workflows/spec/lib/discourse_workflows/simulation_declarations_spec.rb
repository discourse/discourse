# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Simulation::Declaration do
  def core_executable_nodes
    DiscourseWorkflows::Registry
      .nodes(include_disabled_plugins: true)
      .select do |klass|
        plugin = DiscourseWorkflows::Registry.plugin_for(klass)
        plugin.respond_to?(:name) && plugin.name == "discourse-workflows"
      end
      .reject { |klass| klass.identifier.start_with?("trigger:") }
  end

  it "classifies every executed core node" do
    undeclared = core_executable_nodes.reject(&:simulation_declared?).map(&:identifier)

    expect(undeclared).to be_empty
  end

  it "classifies every operation a core node exposes, and nothing else" do
    core_executable_nodes.each do |klass|
      declaration = klass.simulation_declaration
      options = klass.operation_options

      if klass.operation_property?
        expect(declaration.single_mode?).to be(false),
        "#{klass.identifier} declares one mode but has an operation field"
        expect(declaration.declared_operations).to match_array(options),
        "#{klass.identifier} classifies #{declaration.declared_operations.inspect}, " \
          "options are #{options.inspect}"
      else
        expect(declaration.single_mode? || declaration.declared_operations.empty?).to be(true),
        "#{klass.identifier} has no operation field but classifies operations"
      end
    end
  end
end
