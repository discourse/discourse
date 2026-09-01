# frozen_string_literal: true

class Archetype
  include ActiveModel::Serialization

  attr_accessor :id, :options

  class << self
    def default
      "regular"
    end

    def private_message
      "private_message"
    end

    def banner
      "banner"
    end

    def list
      return [] if @archetypes.blank?
      @archetypes.values
    end

    def register(name, options = {})
      @archetypes ||= {}
      @archetypes[name] = Archetype.new(name, options)
    end

    def deregister(name)
      @archetypes ||= {}
      @archetypes.delete(name)
    end
  end
  def initialize(id, options)
    @id = id
    @options = options
  end

  def attributes
    { id: @id, options: @options }
  end

  # default archetypes
  register "regular"
  register "private_message"
  register "banner"
end
