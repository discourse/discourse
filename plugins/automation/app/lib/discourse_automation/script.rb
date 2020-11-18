module DiscourseAutomation
  class Script
    include DiscourseAutomation::ScriptDSL

    attr_reader :automation

    def initialize(automation)
      @automation = automation
    end

    def self.add_script(name, &block)
      @@all_scripts = nil
      define_method("script_#{name}", &block)
    end

    def self.all
      @@all_scripts = DiscourseAutomation::Script
        .instance_methods(false)
        .grep(/^script_/)
    end

    def self.script_for_automation(automation)
      script_method = DiscourseAutomation::Script
        .instance_methods(false)
        .grep(/^script_#{automation.script}/).first

      script = DiscourseAutomation::Script.new(automation)
      script.public_send(script_method)
      script
    end
  end
end
