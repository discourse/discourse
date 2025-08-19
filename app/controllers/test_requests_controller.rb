# frozen_string_literal: true

# This controller's actions are only available in the test environment to help with more complex testing requirements
class TestRequestsController < ApplicationController
  if Rails.env.test?
    def test_net_http_timeouts
      net_http = Net::HTTP.new("example.com")

      render json: {
               open_timeout: net_http.open_timeout,
               read_timeout: net_http.read_timeout,
               write_timeout: net_http.write_timeout,
               max_retries: net_http.max_retries,
             }
    end

    def test_net_http_headers
      net_http_get = Net::HTTP::Get.new("example.com")

      render json: net_http_get
    end
  end
end
