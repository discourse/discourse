# frozen_string_literal: true

class TopicSubtype
  include ActiveModel::Serialization

  attr_accessor :id, :options

  def initialize(id, options)
    @id = id
    @options = options
  end

  def attributes
    { 'id' => @id, 'options' => @options }
  end

  def self.list
    return [] unless @archetypes.present?
    @archetypes.values
  end

  def self.user_to_user
    'user_to_user'
  end

  def self.system_message
    'system_message'
  end

  def self.moderator_warning
    'moderator_warning'
  end

  def self.notify_moderators
    'notify_moderators'
  end

  def self.notify_user
    'notify_user'
  end

  def self.pending_users_reminder
    'pending_users'
  end

  def self.register(name, options = {})
    @subtypes ||= {}
    @subtypes[name] = TopicSubtype.new(name, options)
  end

  register 'user_to_user'
  register 'system_message'
  register 'moderator_warning'
  register 'notify_moderators'
  register 'notify_user'

end
