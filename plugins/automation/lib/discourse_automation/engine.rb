# frozen_string_literal: true

module ::DiscourseAutomation
  class Engine < ::Rails::Engine
    engine_name PLUGIN_NAME
    isolate_namespace DiscourseAutomation
  end

  def self.filter_by_trigger(items, trigger)
    trigger = trigger&.to_sym

    indexed_items =
      items.each_with_object({}) do |item, acc|
        if item[:triggerable] == trigger || item[:triggerable].nil?
          acc[item[:name]] = item if acc[item[:name]].nil? || item[:triggerable] == trigger
        end
      end

    indexed_items.values
  end
end
