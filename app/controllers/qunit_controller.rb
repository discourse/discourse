# frozen_string_literal: true

class QunitController < ApplicationController
  skip_before_action *%i{
    check_xhr
    preload_json
    redirect_to_login_if_required
  }
  layout false

  # only used in test / dev
  def index
    raise Discourse::InvalidAccess.new if Rails.env.production?
    if (theme_name = params[:theme_name]).present?
      theme = Theme.find_by(name: theme_name)
      raise Discourse::NotFound if theme.blank?
    elsif (theme_url = params[:theme_url]).present?
      theme = RemoteTheme.find_by(remote_url: theme_url)
      raise Discourse::NotFound if theme.blank?
    end
    if theme.present?
      request.env[:resolved_theme_ids] = [theme.id]
      request.env[:skip_theme_ids_transformation] = true
    end
  end
end
