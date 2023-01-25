# frozen_string_literal: true

module ChatService
  extend ActiveSupport::Concern

  class Failure < StandardError
    attr_reader :context

    def initialize(context = nil)
      @context = context
      super
    end
  end

  class Contract
    include ActiveModel::API
    include ActiveModel::Attributes
    include ActiveModel::AttributeMethods

    def self.model_name
      ActiveModel::Name.new(self, nil, "contract")
    end
  end

  class Context < OpenStruct
    def self.build(context = {})
      self === context ? context : new(context)
    end

    def success?
      !failure?
    end

    def failure?
      @failure || false
    end

    def fail!(context = {})
      merge(context)
      @failure = true
      raise Failure, self
    end

    def called!(service)
      _called << service
    end

    def rollback!
      return false if @rolled_back
      _called.reverse_each(&:rollback)
      @rolled_back = true
    end

    def _called
      @called ||= []
    end

    def merge(other_context = {})
      other_context.each { |key, value| self[key.to_sym] = value }
      self
    end
  end

  included do
    attr_reader :context
    attr_reader :contract
  end

  module ClassMethods
    attr_reader :contract_block

    def call(context = {})
      new(context).tap(&:run).context
    end

    def call!(context = {})
      new(context).tap(&:run!).context
    end

    def contract(&block)
      @contract_block = block
    end

    def around(*hooks, &block)
      hooks << block if block
      hooks.each { |hook| around_hooks.push(hook) }
    end

    def before(*hooks, &block)
      hooks << block if block
      hooks.each { |hook| before_hooks.push(hook) }
    end

    def after(*hooks, &block)
      hooks << block if block
      hooks.each { |hook| after_hooks.unshift(hook) }
    end

    def around_hooks
      @around_hooks ||= []
    end

    def before_hooks
      @before_hooks ||= []
    end

    def after_hooks
      @after_hooks ||= []
    end
  end

  def initialize(initial_context = {})
    @context = Context.build(initial_context)

    if self.class.contract_block
      contract_class = Class.new(Contract)
      contract_class.class_eval(&self.class.contract_block)
      @contract = contract_class.new(initial_context.except(:guardian))
      self.context[:contract] = contract
    end
  end

  def guardian(name, *args)
    context.fail!("guardian.failed" => name) unless context[:guardian].public_send(name, *args)
  end

  def run
    run!
  rescue Failure => exception
    raise if context.object_id != exception.context.object_id
  end

  def run!
    with_hooks do
      if contract
        context.fail!("contract.failed" => true) unless contract.valid?
        context.merge(contract.attributes)
      end

      call
      context.called!(self)
    end
  rescue ActiveRecord::Rollback
    context.rollback!
  rescue StandardError
    context.rollback!
    raise
  end

  def call
  end

  def rollback
  end

  private

  def with_hooks
    run_around_hooks do
      run_before_hooks
      yield
      run_after_hooks
    end
  end

  def run_around_hooks(&block)
    self
      .class
      .around_hooks
      .reverse
      .inject(block) { |chain, hook| proc { run_hook(hook, chain) } }
      .call
  end

  def run_before_hooks
    run_hooks(self.class.before_hooks)
  end

  def run_after_hooks
    run_hooks(self.class.after_hooks)
  end

  def run_hooks(hooks)
    hooks.each { |hook| run_hook(hook) }
  end

  def run_hook(hook, *args)
    hook.is_a?(Symbol) ? send(hook, *args) : instance_exec(*args, &hook)
  end
end
