# frozen_string_literal: true

class DynamicAssetsController < ApplicationController
  before_action :add_cors_header

  def add_cors_header
    cdn_hosts = [GlobalSetting.s3_cdn_url, GlobalSetting.cdn_url]

    if cdn_hosts.include?(params[:hostname])
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Credentials'] = 'false'
    end
  end
end
