# frozen_string_literal: true

module DiscourseAutomation
  class Triggerable
    attr_reader :fields, :name, :not_found

    def initialize(name)
      @name = name
      @placeholders = []
      @fields = []
      @on_update_block = proc {}
      @on_call_block = proc {}
      @not_found = false

      eval! if @name
    end

    def placeholders
      @placeholders.uniq.compact
    end

    def placeholder(placeholder)
      @placeholders << placeholder
    end

    def field(name, component:, extra: {}, accepts_placeholders: false)
      @fields << {
        name: name,
        component: component,
        accepts_placeholders: accepts_placeholders,
        extra: extra
      }
    end

    def components
      fields.map { |f| f[:component] }.uniq
    end

    def eval!
      begin
        public_send("__triggerable_#{name.underscore}")
      rescue NoMethodError
        @not_found = true
      end

      self
    end

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
