# frozen_string_literal: true

# Shared guards and user selection for the group mutation service objects, so
# HTTP controllers and the MCP server apply the same rules.
module GroupMutations
  class UnknownUsers < StandardError
    def initialize(values)
      super(I18n.t("groups.errors.users_not_found", values: values.join(", ")))
    end
  end

  class AutomaticGroup < StandardError
    def initialize(message = nil)
      super(message || I18n.t("groups.errors.can_not_modify_automatic"))
    end
  end

  module_function

  def ensure_not_automatic!(group)
    raise AutomaticGroup if group.automatic
  end

  def resolve_users(
    guardian:,
    usernames: nil,
    user_id: nil,
    user_ids: nil,
    user_emails: nil,
    require_all: false
  )
    # Resolving an address reveals whether it has an account, so this follows the
    # staff-only rule core applies elsewhere via hide_email_address_taken.
    guardian.ensure_can_see_emails! if split_values(user_emails).present?

    if (values = split_values(usernames)).present?
      values = values.map { User.normalize_username(it) }
      found(
        User.where(username_lower: values),
        :username_lower,
        values,
        require_all:,
        error_key: :usernames,
      )
    elsif user_id.present?
      found(User.where(id: user_id.to_i), :id, [user_id.to_i], require_all:, error_key: :user_id)
    elsif (values = split_values(user_ids)).present?
      found(User.where(id: values), :id, values, require_all:, error_key: :user_ids)
    elsif (values = split_values(user_emails)).present?
      values = values.map { Email.downcase(it) }
      found(
        User.with_email(values),
        "user_emails.email",
        values,
        require_all:,
        error_key: :user_emails,
      )
    else
      User.none
    end
  end

  def split_values(value)
    Array.wrap(value).flat_map { it.to_s.split(",") }.map(&:strip).reject(&:blank?)
  end

  def found(users, column, values, require_all:, error_key:)
    if require_all
      missing = values.map(&:to_s) - users.pluck(column).map(&:to_s)
      raise UnknownUsers, missing if missing.present?
    elsif !users.exists?
      raise Discourse::InvalidParameters.new(error_key)
    end
    users
  end
  private_class_method :found
end
