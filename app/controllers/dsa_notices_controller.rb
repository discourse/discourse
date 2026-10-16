# frozen_string_literal: true

class DsaNoticesController < ApplicationController
  skip_before_action :check_xhr, only: :index
  skip_before_action :redirect_to_login_if_required, :redirect_to_profile_if_required
  before_action :ensure_enabled
  before_action :validate_notice_shape, :rate_limit_notice, only: :create

  NOTICE_FIELDS = %w[submission_id content_url explanation anonymous name email declaration].freeze
  BOOLEAN_VALUES = [true, false, "true", "false", "1", "0", 1, 0].freeze
  private_constant :NOTICE_FIELDS, :BOOLEAN_VALUES

  def index
    return render "default/empty" unless request.format.json?

    render json: { site_title: SiteSetting.title }
  end

  def create
    Dsa::SubmitNotice.call(
      service_params.deep_merge(params: params[:notice].permit(*NOTICE_FIELDS).to_h),
    ) do
      on_success do |topic:|
        notice = topic.custom_fields.fetch("dsa_notice")
        render json: {
                 reference: notice["reference"],
                 contact: notice["email"].present?,
               },
               status: :created
      end
      on_failed_contract do |contract|
        render_json_error(contract.errors.full_messages, status: 422)
      end
      on_failed_policy(:matches_submission) do
        render_json_error(I18n.t("dsa_notice.submission_changed"), status: 409)
      end
      on_exceptions do |exception|
        Discourse.warn_exception(
          exception,
          message: "Illegal content notice notifications could not be queued",
        )
        render_json_error(I18n.t("dsa_notice.retry_submission"), status: 503)
      end
      on_failure { render_json_error(I18n.t("dsa_notice.failed"), status: 422) }
    end
  end

  private

  def ensure_enabled
    raise Discourse::NotFound unless SiteSetting.dsa_reporting_enabled
  end

  def validate_notice_shape
    notice = params[:notice]
    valid =
      notice.is_a?(ActionController::Parameters) &&
        NOTICE_FIELDS.all? do |field|
          next true unless notice.key?(field)
          if %w[anonymous declaration].include?(field)
            BOOLEAN_VALUES.include?(notice[field])
          else
            notice[field].is_a?(String)
          end
        end
    render_json_error(I18n.t("dsa_notice.invalid_parameters"), status: 422) unless valid
  end

  def rate_limit_notice
    notice = params[:notice]
    if TopicCustomField.where("char_length(value) < 400").exists?(
         name: "dsa_notice_submission",
         value: notice[:submission_id].to_s.downcase,
       )
      return
    end

    RateLimiter.new(nil, "dsa-notice-ip-#{request.remote_ip}", 5, 1.hour).performed!
    RateLimiter.new(nil, "dsa-notice-global", 100, 1.hour).performed!
    unless ActiveModel::Type::Boolean.new.cast(notice[:anonymous])
      email_key = Digest::SHA256.hexdigest(notice[:email].to_s.strip.downcase)
      RateLimiter.new(nil, "dsa-notice-email-#{email_key}", 3, 1.day).performed!
    end
  end
end
