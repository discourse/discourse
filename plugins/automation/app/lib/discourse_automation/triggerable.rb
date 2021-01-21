# frozen_string_literal: true

module DiscourseAutomation
  class Triggerable
    def initialize(automation)
      @automation = automation
      @on_update_block = Proc.new {}
      @on_call_block = Proc.new {}

      eval!
    end

    def eval!
      public_send("__triggerable_#{automation.trigger.name.underscore}")
      self
    end

    attr_reader :automation

    def on_call(&block)
      if block_given?
        @on_call_block = block
      else
        @on_call_block
      end
    end

    def on_update(&block)
      if block_given?
        @on_update_block = block
      else
        @on_update_block
      end
    end

    def self.add(identifier, &block)
      @@all_triggers = nil
      define_method("__triggerable_#{identifier}", &block)
    end

    def self.all
      @@all_triggers ||= DiscourseAutomation::Triggerable
        .instance_methods(false)
        .grep(/^__triggerable_/)
    end
  end
end
