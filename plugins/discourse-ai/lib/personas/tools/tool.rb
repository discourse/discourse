# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Tool
        # Why 30 mega bytes?
        # This general limit is mainly a security feature to avoid tools
        # forcing infinite downloads or causing memory exhaustion.
        # The limit is somewhat arbitrary and can be increased in future if needed.
        MAX_RESPONSE_BODY_LENGTH = 30.megabytes

        class << self
          def signature
            raise NotImplemented
          end

          def name
            raise NotImplemented
          end

          def custom?
            false
          end

          def accepted_options
            []
          end

          def option(name, type:, values: nil, default: nil)
            Option.new(tool: self, name: name, type: type, values: values, default: default)
          end

          def help
            I18n.t("discourse_ai.ai_bot.tool_help.#{signature[:name]}")
          end

          def custom_system_message
            nil
          end

          def allow_partial_tool_calls?
            false
          end

          def inject_prompt(prompt:, context:, persona:)
          end
        end

        # llm being public makes it a bit easier to test
        attr_accessor :custom_raw, :parameters, :llm, :provider_data
        attr_reader :tool_call_id, :persona_options, :bot_user, :context

        def initialize(
          parameters,
          tool_call_id: "",
          persona_options: {},
          bot_user:,
          llm:,
          context: nil,
          provider_data: {}
        )
          @parameters = parameters
          @tool_call_id = tool_call_id
          @persona_options = persona_options
          @bot_user = bot_user
          @llm = llm
          @context = context.nil? ? DiscourseAi::Personas::BotContext.new(messages: []) : context
          @provider_data = provider_data.is_a?(Hash) ? provider_data.deep_symbolize_keys : {}
          if !@context.is_a?(DiscourseAi::Personas::BotContext)
            raise ArgumentError, "context must be a DiscourseAi::Personas::Context"
          end
        end

        def name
          self.class.name
        end

        def summary
          I18n.t("discourse_ai.ai_bot.tool_summary.#{name}")
        end

        def details
          I18n.t("discourse_ai.ai_bot.tool_description.#{name}", description_args)
        end

        def help
          I18n.t("discourse_ai.ai_bot.tool_help.#{name}")
        end

        def options
          result = ActiveSupport::HashWithIndifferentAccess.new
          self.class.accepted_options.each do |option|
            val = @persona_options[option.name]
            if val
              case option.type
              when :boolean
                val = (val.to_s == "true")
              when :integer
                val = val.to_i
              when :enum
                val = val.to_s
                val = option.default if option.values && !option.values.include?(val)
              end
              result[option.name] = val
            elsif val.nil?
              result[option.name] = option.default
            end
          end
          result
        end

        def chain_next_response?
          true
        end

        protected

        def fetch_default_branch(repo)
          api_url = "https://api.github.com/repos/#{repo}"

          response_code = "unknown error"
          repo_data = nil

          send_http_request(
            api_url,
            headers: {
              "Accept" => "application/vnd.github.v3+json",
            },
            authenticate_github: true,
          ) do |response|
            response_code = response.code
            if response_code == "200"
              begin
                repo_data = JSON.parse(read_response_body(response))
              rescue JSON::ParserError
                response_code = "500 - JSON parse error"
              end
            end
          end

          response_code == "200" ? repo_data["default_branch"] : "main"
        end

        def send_http_request(
          url,
          headers: {},
          authenticate_github: false,
          follow_redirects: false,
          method: :get,
          body: nil,
          &blk
        )
          self.class.send_http_request(
            url,
            headers: headers,
            authenticate_github: authenticate_github,
            follow_redirects: follow_redirects,
            method: method,
            body: body,
            &blk
          )
        end

        def self.send_http_request(
          url,
          headers: {},
          authenticate_github: false,
          follow_redirects: false,
          method: :get,
          body: nil
        )
          raise "Expecting caller to use a block" if !block_given?

          uri = nil
          url = UrlHelper.normalized_encode(url)
          uri =
            begin
              URI.parse(url)
            rescue StandardError
              nil
            end

          return if !uri

          if follow_redirects
            fd =
              FinalDestination.new(
                url,
                validate_uri: true,
                max_redirects: 5,
                follow_canonical: true,
              )

            uri = fd.resolve
          end

          return if uri.blank?

          request = nil
          if method == :get
            request = FinalDestination::HTTP::Get.new(uri)
          elsif method == :post
            request = FinalDestination::HTTP::Post.new(uri)
          elsif method == :put
            request = FinalDestination::HTTP::Put.new(uri)
          elsif method == :patch
            request = FinalDestination::HTTP::Patch.new(uri)
          elsif method == :delete
            request = FinalDestination::HTTP::Delete.new(uri)
          end

          raise ArgumentError, "Invalid method: #{method}" if !request

          request.body = body if body

          request["User-Agent"] = DiscourseAi::AiBot::USER_AGENT
          headers.each { |k, v| request[k] = v }
          if authenticate_github && SiteSetting.ai_bot_github_access_token.present?
            request["Authorization"] = "Bearer #{SiteSetting.ai_bot_github_access_token}"
          end

          FinalDestination::HTTP.start(uri.hostname, uri.port, use_ssl: uri.port != 80) do |http|
            http.request(request) { |response| yield response }
          end
        end

        def self.read_response_body(response, max_length: nil)
          max_length ||= MAX_RESPONSE_BODY_LENGTH

          body = +""
          response.read_body do |chunk|
            body << chunk
            break if body.bytesize > max_length
          end

          if body.bytesize > max_length
            body[0...max_length].scrub
          else
            body.scrub
          end
        end

        def read_response_body(response, max_length: nil)
          self.class.read_response_body(response, max_length: max_length)
        end

        def truncate(text, llm:, percent_length: nil, max_length: nil)
          if !percent_length && !max_length
            raise ArgumentError, "You must provide either percent_length or max_length"
          end

          target = llm.max_prompt_tokens
          target = (target * percent_length).to_i if percent_length

          if max_length
            target = max_length if target > max_length
          end

          llm.tokenizer.truncate(text, target, strict: SiteSetting.ai_strict_token_counting)
        end

        def accepted_options
          []
        end

        def option(name, type:)
          Option.new(tool: self, name: name, type: type)
        end

        def description_args
          {}
        end

        def format_results(rows, column_names = nil, args: nil)
          rows = rows&.map { |row| yield row } if block_given?

          if !column_names
            index = -1
            column_indexes = {}

            rows =
              rows&.map do |data|
                new_row = []
                data.each do |key, value|
                  found_index = column_indexes[key.to_s] ||= (index += 1)
                  new_row[found_index] = value
                end
                new_row
              end
            column_names = column_indexes.keys
          end

          # this is not the most efficient format
          # however this is needed cause GPT 3.5 / 4 was steered using JSON
          result = { column_names: column_names, rows: rows }
          result[:args] = args if args
          result
        end
      end
    end
  end
end
