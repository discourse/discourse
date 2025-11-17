# frozen_string_literal: true

module SiteSettings
end

class SiteSettings::DependencyGraph
  include TSort

  def initialize(dependencies = {})
    @dependencies = dependencies
  end

  def []=(setting, value)
    dependencies[setting] = value
  end

  def order
    @order ||= tsort
  end

  private

  attr_reader :dependencies

  def tsort_each_child(node, &block)
    dependencies.fetch(node, []).each(&block)
  end

  def tsort_each_node(&block)
    dependencies.each_key(&block)
  end
end
