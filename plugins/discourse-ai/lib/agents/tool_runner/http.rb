# frozen_string_literal: true

module DiscourseAi
  module Agents
    class ToolRunner
      module HTTP
        def attach_http(mini_racer_context)
          mini_racer_context.attach(
            "_http_get",
            ->(url, options) do
              begin
                @http_requests_made += 1
                if @http_requests_made > MAX_HTTP_REQUESTS
                  raise TooManyRequestsError.new("Tool made too many HTTP requests")
                end

                in_attached_function do
                  headers = (options && options["headers"]) || {}
                  base64_encode = options && options["base64Encode"]

                  result = {}
                  DiscourseAi::Agents::Tools::Tool.send_http_request(
                    url,
                    headers: headers,
                  ) do |response|
                    if base64_encode
                      result[:body] = Base64.strict_encode64(response.body)
                    else
                      result[:body] = response.body
                    end
                    result[:status] = response.code.to_i
                  end

                  result
                end
              end
            end,
          )

          %i[post put patch delete].each do |method|
            mini_racer_context.attach(
              "_http_#{method}",
              ->(url, options) do
                begin
                  @http_requests_made += 1
                  if @http_requests_made > MAX_HTTP_REQUESTS
                    raise TooManyRequestsError.new("Tool made too many HTTP requests")
                  end

                  in_attached_function do
                    headers = (options && options["headers"]) || {}
                    body = options && options["body"]
                    base64_encode = options && options["base64Encode"]

                    result = {}
                    DiscourseAi::Agents::Tools::Tool.send_http_request(
                      url,
                      method: method,
                      headers: headers,
                      body: body,
                    ) do |response|
                      if base64_encode
                        result[:body] = Base64.strict_encode64(response.body)
                      else
                        result[:body] = response.body
                      end
                      result[:status] = response.code.to_i
                    end

                    result
                  rescue => e
                    if Rails.env.development?
                      p url
                      p options
                      p e
                      puts e.backtrace
                    end
                    raise e
                  end
                end
              end,
            )
          end
        end
      end
    end
  end
end
