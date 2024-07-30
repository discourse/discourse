# frozen_string_literal: true

module ReadOnlyMixin
  module ClassMethods
    def actions_allowed_in_staff_writes_only_mode
      @actions_allowed_in_staff_writes_only_mode ||= []
    end

    def allow_in_staff_writes_only_mode(*actions)
      actions_allowed_in_staff_writes_only_mode.concat(actions.map(&:to_sym))
    end

    def allowed_in_staff_writes_only_mode?(action_name)
      actions_allowed_in_staff_writes_only_mode.include?(action_name.to_sym)
    end
  end

  def staff_writes_only_mode?
    @staff_writes_only_mode
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

  def get_or_check_readonly_mode
    check_readonly_mode if @readonly_mode.nil?
    @readonly_mode
  end

  def get_or_check_staff_writes_only_mode
    check_readonly_mode if @staff_writes_only_mode.nil?
    @staff_writes_only_mode
  end

  def add_readonly_header
    response.headers["Discourse-Readonly"] = "true" if @readonly_mode
  end

  def allowed_in_staff_writes_only_mode?
    self.class.allowed_in_staff_writes_only_mode?(action_name)
  end

  def block_if_readonly_mode
    return if request.fullpath.start_with?(path "/admin/backups")
    return if request.fullpath.start_with?(path "/categories/search")
    return if request.get? || request.head?

    if @staff_writes_only_mode
      raise Discourse::ReadOnly.new if !current_user&.staff? && !allowed_in_staff_writes_only_mode?
    elsif @readonly_mode
      raise Discourse::ReadOnly.new
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end
end
