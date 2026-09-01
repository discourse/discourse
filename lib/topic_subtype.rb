# frozen_string_literal: true

class TopicSubtype
  include ActiveModel::Serialization

  attr_accessor :id, :options

  class << self
    def list
      return [] if @archetypes.blank?
      @archetypes.values
    end

    def user_to_user
      "user_to_user"
    end

    def system_message
      "system_message"
    end

    def moderator_warning
      "moderator_warning"
    end

    def notify_moderators
      "notify_moderators"
    end

    def notify_user
      "notify_user"
    end

    def pending_users_reminder
      "pending_users"
    end

    def register(name, options = {})
      @subtypes ||= {}
      @subtypes[name] = TopicSubtype.new(name, options)
    end
  end
  def initialize(id, options)
    @id = id
    @options = options
  end

  def attributes
    { "id" => @id, "options" => @options }
  end

  register "user_to_user"
  register "system_message"
  register "moderator_warning"
  register "notify_moderators"
  register "notify_user"
end
