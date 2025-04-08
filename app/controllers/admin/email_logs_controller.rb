# frozen_string_literal: true

class Admin::EmailLogsController < Admin::AdminController
  def sent
    email_logs = EmailLog.joins(<<~SQL)
      LEFT JOIN post_reply_keys
      ON post_reply_keys.post_id = email_logs.post_id
      AND post_reply_keys.user_id = email_logs.user_id
    SQL

    email_logs = filter_logs(email_logs, params)

    if (reply_key = params[:reply_key]).present?
      email_logs =
        if reply_key.length == 32
          email_logs.where("post_reply_keys.reply_key = ?", reply_key)
        else
          email_logs.where(
            "replace(post_reply_keys.reply_key::VARCHAR, '-', '') ILIKE ?",
            "%#{reply_key}%",
          )
        end
    end

    email_logs = email_logs.to_a

    tuples = email_logs.map { |email_log| [email_log.post_id, email_log.user_id] }

    reply_keys = {}

    if tuples.present?
      PostReplyKey
        .where("(post_id,user_id) IN (#{(["(?)"] * tuples.size).join(", ")})", *tuples)
        .pluck(:post_id, :user_id, "reply_key::text")
        .each { |post_id, user_id, key| reply_keys[[post_id, user_id]] = key }
    end

    render_serialized(email_logs, EmailLogSerializer, reply_keys: reply_keys)
  end

  def skipped
    skipped_email_logs = filter_logs(SkippedEmailLog, params)
    render_serialized(skipped_email_logs, SkippedEmailLogSerializer)
  end

  def bounced
    email_logs = filter_logs(EmailLog.bounced, params)
    render_serialized(email_logs, EmailLogSerializer)
  end

  def received
    incoming_emails = filter_incoming_emails(IncomingEmail, params)
    render_serialized(incoming_emails, IncomingEmailSerializer)
  end

  def rejected
    incoming_emails = filter_incoming_emails(IncomingEmail.errored, params)
    render_serialized(incoming_emails, IncomingEmailSerializer)
  end

  def incoming
    params.require(:id)
    incoming_email = IncomingEmail.find(params[:id].to_i)
    serializer = IncomingEmailDetailsSerializer.new(incoming_email, root: false)
    render_json_dump(serializer)
  end

  def incoming_from_bounced
    params.require(:id)

    begin
      email_log = EmailLog.find_by(id: params[:id].to_i, bounced: true)
      raise Discourse::InvalidParameters if email_log&.bounce_key.blank?

      if Email::Sender.bounceable_reply_address?
        bounced_to_address = Email::Sender.bounce_address(email_log.bounce_key)
        incoming_email = IncomingEmail.find_by(to_addresses: bounced_to_address)
      end

      if incoming_email.nil?
        email_local_part, email_domain = SiteSetting.notification_email.split("@")
        bounced_to_address = "#{email_local_part}+verp-#{email_log.bounce_key}@#{email_domain}"
        incoming_email = IncomingEmail.find_by(to_addresses: bounced_to_address)
      end

      # Temporary fix until all old format of emails has been purged via lib/email/cleaner.rb
      if incoming_email.nil?
        email_local_part, email_domain = SiteSetting.reply_by_email_address.split("@")
        subdomain, root_domain, extension = email_domain&.split(".")
        bounced_to_address = "#{subdomain}+verp-#{email_log.bounce_key}@#{root_domain}.#{extension}"
        incoming_email = IncomingEmail.find_by(to_addresses: bounced_to_address)
      end

      raise Discourse::NotFound if incoming_email.nil?

      serializer = IncomingEmailDetailsSerializer.new(incoming_email, root: false)
      render_json_dump(serializer)
    rescue => e
      render json: { errors: [e.message] }, status: 404
    end
  end

  private

  def filter_logs(logs, params)
    table_name = logs.table_name

    logs =
      logs
        .includes(:user, post: :topic)
        .references(:user)
        .order(created_at: :desc)
        .offset(params[:offset] || 0)
        .limit(50)

    logs = logs.where("users.username ILIKE ?", "%#{params[:user]}%") if params[:user].present?

    if params[:address].present?
      query = "#{table_name}.to_address ILIKE :address"
      query += " OR #{table_name}.cc_addresses ILIKE :address"

      logs = logs.where(query, { address: "%#{params[:address]}%" })
    end

    logs = logs.where("#{table_name}.email_type ILIKE ?", "%#{params[:type]}%") if params[
      :type
    ].present?

    if table_name == "email_logs" && params[:smtp_transaction_response].present?
      logs =
        logs.where(
          "#{table_name}.smtp_transaction_response ILIKE ?",
          "%#{params[:smtp_transaction_response]}%",
        )
    end

    logs
  end

  def filter_incoming_emails(incoming_emails, params)
    incoming_emails =
      incoming_emails
        .includes(:user, post: :topic)
        .order(created_at: :desc)
        .offset(params[:offset] || 0)
        .limit(50)

    incoming_emails = incoming_emails.where("from_address ILIKE ?", "%#{params[:from]}%") if params[
      :from
    ].present?
    incoming_emails =
      incoming_emails.where(
        "to_addresses ILIKE :to OR cc_addresses ILIKE :to",
        to: "%#{params[:to]}%",
      ) if params[:to].present?
    incoming_emails = incoming_emails.where("subject ILIKE ?", "%#{params[:subject]}%") if params[
      :subject
    ].present?
    incoming_emails = incoming_emails.where("error ILIKE ?", "%#{params[:error]}%") if params[
      :error
    ].present?

    incoming_emails
  end
end
