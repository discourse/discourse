# frozen_string_literal: true

class Admin::CommandCenterController < Admin::AdminController
  QUICK_USER_LIMIT = 5

  def users
    term = params[:term].to_s.strip.delete_prefix("@")

    return render_json_dump(users: []) if term.length < 2

    escaped_term = ActiveRecord::Base.sanitize_sql_like(term.downcase)
    prefix_term = "#{escaped_term}%"
    users = User.real.not_staged

    if term.include?("@")
      users =
        users
          .joins(:user_emails)
          .where(
            "users.username_lower LIKE :term OR user_emails.email ILIKE :term",
            term: prefix_term,
          )
          .distinct
    else
      users = users.where("users.username_lower LIKE :term", term: prefix_term)
    end

    users = users.order(:username_lower).limit(QUICK_USER_LIMIT)

    render_json_dump(
      users:
        ActiveModel::ArraySerializer.new(
          users,
          each_serializer: Admin::CommandCenterUserSerializer,
          root: false,
          scope: guardian,
        ).as_json,
    )
  end

  def preview
    Admin::CommandCenter::SuspendUserPreview.call(service_params) do
      on_success { |payload:| render_json_dump(payload) }
      on_failed_contract do |contract|
        render json: failed_json.merge(message: contract.errors.full_messages.first),
               status: :bad_request
      end
      on_failed_step(:parse_command) do |step|
        render json: failed_json.merge(message: step.error), status: :unprocessable_entity
      end
      on_failed_step(:ensure_supported_intent) do |step|
        render json: failed_json.merge(message: step.error), status: :unprocessable_entity
      end
      on_model_not_found(:user) do |parsed_command:|
        render json:
                 failed_json.merge(
                   message: "I could not find a user named #{parsed_command[:username]}.",
                   candidates:
                     Admin::CommandCenter::SuspendUserPreview.candidates_for(
                       parsed_command[:username],
                     ),
                 ),
               status: :not_found
      end
      on_failed_policy(:can_suspend_user) { raise Discourse::InvalidAccess }
    end
  end
end
