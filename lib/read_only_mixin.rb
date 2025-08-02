# frozen_string_literal: true

module ReadOnlyMixin
  module ClassMethods
    def actions_allowed_in_readonly_mode
      @actions_allowed_in_readonly_mode ||= []
    end

    def actions_allowed_in_staff_writes_only_mode
      @actions_allowed_in_staff_writes_only_mode ||= []
    end

    def allow_in_readonly_mode(*actions)
      actions_allowed_in_readonly_mode.concat(actions.map(&:to_sym))
    end

    def allow_in_staff_writes_only_mode(*actions)
      actions_allowed_in_staff_writes_only_mode.concat(actions.map(&:to_sym))
    end

    def allowed_in_readonly_mode?(action)
      actions_allowed_in_readonly_mode.include?(action.to_sym)
    end

    def allowed_in_staff_writes_only_mode?(action)
      actions_allowed_in_staff_writes_only_mode.include?(action.to_sym)
    end
  end

  def check_readonly_mode
    if Discourse.readonly_mode?
      @readonly_mode = true
      @staff_writes_only_mode = false
    elsif Discourse.staff_writes_only_mode?
      @readonly_mode = true
      @staff_writes_only_mode = true
    else
      @readonly_mode = false
      @staff_writes_only_mode = false
    end
  end

  def add_readonly_header
    response.headers["Discourse-Readonly"] = "true" if @readonly_mode
  end

  def allowed_in_readonly_mode?
    self.class.allowed_in_readonly_mode?(action_name)
  end

  def allowed_in_staff_writes_only_mode?
    self.class.allowed_in_staff_writes_only_mode?(action_name)
  end

  def block_if_readonly_mode
    return if request.get? || request.head?
    if @staff_writes_only_mode && (allowed_in_staff_writes_only_mode? || current_user&.staff?)
      return
    end
    return if !@readonly_mode || allowed_in_readonly_mode?
    raise Discourse::ReadOnly
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
