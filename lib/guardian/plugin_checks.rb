# frozen_string_literal: true

module PluginChecks
  def self.included(mod)
    mod.instance_methods.each do |method_name|
      if method_name.to_s =~ /\Acan_(.*)/
        method = mod.instance_method(method_name)
        check_name = Regexp.last_match[1].chomp("?")
        mod.define_method(method_name) do |*args, **kwargs|
          result = true
          return false unless PluginChecks.pass?(self, :before, check_name, result, *args, **kwargs)
          result = method.bind(self).call(*args, **kwargs)
          PluginChecks.pass?(self, :after, check_name, result, *args, **kwargs)
        end
      end
    end
  end

  def self.pass?(instance, check_type, check_name, result, *args, **kwargs)
    return result unless DiscoursePluginRegistry.guardian_checks[check_type].present?
    checks = DiscoursePluginRegistry.guardian_checks[check_type][check_name.to_sym]
    return result if checks.blank?
    checks.each { |check| result = check[:proc].call(instance, result, *args, **kwargs) }
    !!result
  end
end
