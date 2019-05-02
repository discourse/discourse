# frozen_string_literal: true

class Archetype
  include ActiveModel::Serialization

  attr_accessor :id, :options

  def initialize(id, options)
    @id = id
    @options = options
  end

  def attributes
    {
      id: @id,
      options: @options
    }
  end

  def self.default
    'regular'
  end

  def self.private_message
    'private_message'
  end

  def self.banner
    'banner'
  end

  def self.list
    return [] unless @archetypes.present?
    @archetypes.values
  end

  def self.register(name, options = {})
    @archetypes ||= {}
    @archetypes[name] = Archetype.new(name, options)
  end

  # default archetypes
  register 'regular'
  register 'private_message'
  register 'banner'

end
