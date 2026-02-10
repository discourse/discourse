# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::DependencyGraph
  include TSort

  attr_reader :dependencies, :behaviors

  def initialize(dependencies = {})
    @dependencies = dependencies
    @behaviors = {}
  end

  def []=(setting, value)
    dependencies[setting] = value
  end

  def [](setting)
    dependencies[setting]
  end

  def reverse_dependencies
    @reverse_dependencies ||=
      begin
        rev = {}
        dependencies.each do |setting, deps|
          Array(deps).each { |dep| (rev[dep.to_s] ||= []) << setting }
        end
        rev
      end
  end

  def dependents(setting)
    reverse_dependencies.fetch(setting.to_s, [])
  end

  def change_behavior(setting, behavior)
    behavior = behavior.to_sym
    raise ArgumentError.new("Behavior must be :hidden") unless behavior == :hidden
    behaviors[setting] = behavior
  end

  def order
    @order ||= tsort
  end

  private

  def tsort_each_child(node, &block)
    dependencies.fetch(node, []).each(&block)
  end

  def tsort_each_node(&block)
    dependencies.each_key(&block)
  end
end
