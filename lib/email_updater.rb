# frozen_string_literal: true

class EmailUpdater
  include HasErrors

  attr_reader :user

  def initialize(guardian = nil, user = nil)
    @guardian = guardian
    @user = user
  end

  def self.human_attribute_name(name, options = {})
    User.human_attribute_name(name, options)
  end

  def authorize_both?
    @user.staff?
  end

  def change_to(email_input)
    @guardian.ensure_can_edit_email!(@user)

    email = Email.downcase(email_input.strip)
    EmailValidator.new(attributes: :email).validate_each(self, :email, email)

    if existing_user = User.find_by_email(email)
      if SiteSetting.hide_email_address_taken
        Jobs.enqueue(:critical_user_email, type: :account_exists, user_id: existing_user.id)
      else
        error_message = +'change_email.error'
        error_message << '_staged' if existing_user.staged?
        errors.add(:base, I18n.t(error_message))
      end
    end

    if errors.blank? && existing_user.nil?
      args = {
        old_email: @user.email,
        new_email: email,
      }

      if authorize_both?
        args[:change_state] = EmailChangeRequest.states[:authorizing_old]
        email_token = @user.email_tokens.create!(email: args[:old_email])
        args[:old_email_token] = email_token
      else
        args[:change_state] = EmailChangeRequest.states[:authorizing_new]
        email_token = @user.email_tokens.create!(email: args[:new_email])
        args[:new_email_token] = email_token
      end
      @user.email_change_requests.create!(args)

      if args[:change_state] == EmailChangeRequest.states[:authorizing_new]
        send_email(:confirm_new_email, email_token)
      elsif args[:change_state] == EmailChangeRequest.states[:authorizing_old]
        send_email(:confirm_old_email, email_token)
      end
    end
  end

  def confirm(token)
    confirm_result = nil
    change_req = nil

    User.transaction do
      result = EmailToken.atomic_confirm(token)
      if result[:success]
        token = result[:email_token]
        @user = token.user

        change_req = user.email_change_requests
          .where('old_email_token_id = :token_id OR new_email_token_id = :token_id', token_id: token.id)
          .first

        # Simple state machine
        case change_req.try(:change_state)
        when EmailChangeRequest.states[:authorizing_old]
          new_token = user.email_tokens.create(email: change_req.new_email)
          change_req.update_columns(change_state: EmailChangeRequest.states[:authorizing_new],
                                    new_email_token_id: new_token.id)
          send_email(:confirm_new_email, new_token)
          confirm_result = :authorizing_new
        when EmailChangeRequest.states[:authorizing_new]
          change_req.update_column(:change_state, EmailChangeRequest.states[:complete])
          user.primary_email.update!(email: token.email)
          user.set_automatic_groups
          confirm_result = :complete
        end
      else
        errors.add(:base, I18n.t('change_email.already_done'))
        confirm_result = :error
      end
    end

    if confirm_result == :complete && change_req.old_email_token_id.blank?
      notify_old(change_req.old_email, token.email)
    end

    confirm_result || :error
  end

  protected

  def notify_old(old_email, new_email)
    Jobs.enqueue :critical_user_email,
                 to_address: old_email,
                 type: :notify_old_email,
                 user_id: @user.id
  end

  def send_email(type, email_token)
    Jobs.enqueue :critical_user_email,
                 to_address: email_token.email,
                 type: type,
                 user_id: @user.id,
                 email_token: email_token.token
  end

end
