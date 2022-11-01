# frozen_string_literal: true

module Onebox
  class StatusCheck
    def initialize(url, options = Onebox.options)
      @url = url
      @options = options
      @status = -1
    end

    def ok?
      status > 199 && status < 300
    end

    def status
      check if @status == -1
      @status
    end

    def human_status
      case status
      when 0
        :connection_error
      when 200..299
        :success
      when 400..499
        :client_error
      when 500..599
        :server_error
      else
        :unknown_error
      end
    end

    private

    def check
      status, headers = FinalDestination.new(@url).small_get({})
      @status = status
    rescue Timeout::Error, Errno::ECONNREFUSED, Net::HTTPError, SocketError
      @status = 0
    end
  end
end
