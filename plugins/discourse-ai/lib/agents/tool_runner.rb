# frozen_string_literal: true

require_relative "tool_runner/http"
require_relative "tool_runner/llm"
require_relative "tool_runner/index"
require_relative "tool_runner/upload"
require_relative "tool_runner/discourse"
require_relative "tool_runner/crypto"

module DiscourseAi
  module Agents
    class ToolRunner
      attr_reader :tool, :parameters, :llm
      attr_accessor :running_attached_function, :timeout, :custom_raw

      TooManyRequestsError = Class.new(StandardError)

      DEFAULT_TIMEOUT = 2000
      MAX_MEMORY = 10_000_000
      MARSHAL_STACK_DEPTH = 20
      MAX_HTTP_REQUESTS = 20

      MAX_SLEEP_CALLS = 30
      MAX_SLEEP_DURATION_MS = 60_000

      MAX_CUSTOM_FIELD_KEY_LENGTH = 256
      MAX_CUSTOM_FIELD_VALUE_LENGTH = 1024

      CUSTOM_FIELD_MODELS = { "post" => Post, "topic" => Topic, "user" => User }.freeze

      include HTTP
      include Llm
      include Index
      include Upload
      include Discourse
      include Crypto

      def initialize(
        parameters:,
        llm:,
        bot_user:,
        context: nil,
        tool:,
        timeout: nil,
        secret_bindings: nil
      )
        if context && !context.is_a?(DiscourseAi::Agents::BotContext)
          raise ArgumentError, "context must be a BotContext object"
        end

        context ||= DiscourseAi::Agents::BotContext.new

        @parameters = parameters
        @llm = llm
        @bot_user = bot_user
        @context = context
        @tool = tool
        @timeout = timeout || DEFAULT_TIMEOUT
        @running_attached_function = false
        @secret_bindings = secret_bindings

        @sleep_calls_made = 0
        @http_requests_made = 0
      end

      def system_guardian
        @system_guardian ||= Guardian.new(::Discourse.system_user)
      end

      def resolve_user(username)
        if username.present?
          User.find_by(username: username)
        else
          @bot_user || ::Discourse.system_user
        end
      end

      def resolve_guardian(username)
        user = resolve_user(username)
        return nil, nil if user.nil?
        guardian =
          if user.staged?
            @context.guardian || system_guardian
          else
            Guardian.new(user)
          end

        [user, guardian]
      end

      def resolve_category(category_id_or_name)
        if category_id_or_name.is_a?(Integer) ||
             category_id_or_name.to_i.to_s == category_id_or_name.to_s
          Category.find_by(id: category_id_or_name.to_i)
        else
          Category
            .where(name: category_id_or_name)
            .or(Category.where(slug: category_id_or_name))
            .first
        end
      end

      def mini_racer_context
        @mini_racer_context ||=
          begin
            ctx =
              MiniRacer::Context.new(
                max_memory: MAX_MEMORY,
                marshal_stack_depth: MARSHAL_STACK_DEPTH,
              )
            attach_truncate(ctx)
            attach_http(ctx)
            attach_index(ctx)
            attach_upload(ctx)
            attach_chain(ctx)
            attach_secrets(ctx)
            attach_crypto(ctx)
            attach_sleep(ctx)
            attach_discourse(ctx)
            ctx.eval(framework_script)
            ctx
          end
      end

      def framework_script
        http_methods = %i[get post put patch delete].map { |method| <<~JS }.join("\n")
          #{method}: function(url, options) {
            return _http_#{method}(url, options);
          },
          JS
        <<~JS
        const http = {
          #{http_methods}
        };

        const llm = {
          truncate: _llm_truncate,
          generate: function(prompt, options) {
            const result = _llm_generate(prompt, options);
            if (options && options.json) {
              try {
                return JSON.parse(result);
              } catch (e) {
                return result;
              }
            }
            return result;
          },
        };

        const index = {
          search: _index_search,
          getFile: _index_get_file,
        }

        const upload = {
          create: _upload_create,
          getUrl: _upload_get_url,
          getBase64: function(id, maxPixels) {
            return _upload_get_base64(id, maxPixels);
          }
        }

        const chain = {
          setCustomRaw: _chain_set_custom_raw,
          streamCustomRaw: _chain_stream_custom_raw,
        };

        const secrets = {
          get: function(aliasName) {
            return _secrets_get(aliasName);
          },
        };

        const crypto = {
          hmacSha256: function(key, data) {
            return _crypto_hmac_sha256_hex(key, data);
          },
          hmacSha1: function(key, data) {
            return _crypto_hmac_sha1_hex(key, data);
          },
          hmacSha256Base64: function(key, data) {
            return _crypto_hmac_sha256_base64(key, data);
          },
          hmacSha1Base64: function(key, data) {
            return _crypto_hmac_sha1_base64(key, data);
          },
          hmacSha256Bytes: function(key, data) {
            return _crypto_hmac_sha256_bytes(key, data);
          },
          hmacSha1Bytes: function(key, data) {
            return _crypto_hmac_sha1_bytes(key, data);
          },
          sha256: function(data) {
            return _crypto_sha256_hex(data);
          },
          sha1: function(data) {
            return _crypto_sha1_hex(data);
          },
          md5: function(data) {
            return _crypto_md5_hex(data);
          },
          sha256Base64: function(data) {
            return _crypto_sha256_base64(data);
          },
          sha1Base64: function(data) {
            return _crypto_sha1_base64(data);
          },
          md5Base64: function(data) {
            return _crypto_md5_base64(data);
          },
          sha256Bytes: function(data) {
            return _crypto_sha256_bytes(data);
          },
          sha1Bytes: function(data) {
            return _crypto_sha1_bytes(data);
          },
          base64Encode: function(text) {
            return _crypto_base64_encode(text);
          },
          base64Decode: function(base64) {
            return _crypto_base64_decode(base64);
          },
          base64UrlEncode: function(text) {
            return _crypto_base64_url_encode(text);
          },
          base64UrlDecode: function(base64) {
            return _crypto_base64_url_decode(base64);
          },
          signRsaSha256: function(pemPrivateKey, data) {
            return _crypto_sign_rsa_sha256(pemPrivateKey, data);
          },
          signRsaSha1: function(pemPrivateKey, data) {
            return _crypto_sign_rsa_sha1(pemPrivateKey, data);
          },
          randomBytes: function(length) {
            return _crypto_random_bytes(length);
          },
        };

        const discourse = {
          baseUrl: #{::Discourse.base_url.to_json},
          search: function(params) {
            return _discourse_search(params);
          },
          updateAgent: function(agent_id_or_name, updates) {
            const result = _discourse_update_agent(agent_id_or_name, updates);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          getPost: _discourse_get_post,
          getTopic: _discourse_get_topic,
          filterTopics: function(params) {
            const result = _discourse_filter_topics(params || {});
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          getUser: _discourse_get_user,
          getAgent: function(name) {
            const agentDetails = _discourse_get_agent(name);
            if (agentDetails.error) {
              throw new Error(agentDetails.error);
            }

            // merge result.agent with {}..
            return Object.assign({
              update: function(updates) {
                const result = _discourse_update_agent(name, updates);
                if (result.error) {
                  throw new Error(result.error);
                }
                return result;
              },
              respondTo: function(params) {
                const result = _discourse_respond_to_agent(name, params);
                if (result.error) {
                  throw new Error(result.error);
                }
                return result;
              }
            }, agentDetails.agent);
          },
          createChatMessage: function(params) {
            const result = _discourse_create_chat_message(params);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          createStagedUser: function(params) {
            const result = _discourse_create_staged_user(params);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          createTopic: function(params) {
            const result = _discourse_create_topic(params);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          createPost: function(params) {
            const result = _discourse_create_post(params);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          editPost: function(post_id, raw, options) {
            const result = _discourse_edit_post(post_id, raw, options);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          editTopic: function(topic_id, updates, options) {
            const result = _discourse_edit_topic(topic_id, updates, options);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          // Backwards compatibility alias (undocumented)
          setTags: function(topic_id, tags, options) {
            return this.editTopic(topic_id, { tags: tags }, options);
          },
          getCustomField: function(type, id, key) {
            const result = _discourse_get_custom_field(type, id, key);
            if (result && result.error) {
              throw new Error(result.error);
            }
            return result;
          },
          setCustomField: function(type, id, key, value) {
            const result = _discourse_set_custom_field(type, id, key, value);
            if (result.error) {
              throw new Error(result.error);
            }
            return result;
          },
        };

        const context = #{JSON.generate(@context.to_json)};

        function details() { return ""; };
      JS
      end

      def details
        eval_with_timeout("details()")
      end

      def eval_with_timeout(script, timeout: nil)
        timeout ||= @timeout
        mutex = Mutex.new
        done = false
        elapsed = 0

        t =
          Thread.new do
            begin
              while !done
                # this is not accurate. but reasonable enough for a timeout
                sleep(0.001)
                elapsed += 1 if !self.running_attached_function
                if elapsed > timeout
                  mutex.synchronize { mini_racer_context.stop unless done }
                  break
                end
              end
            rescue => e
              STDERR.puts e
              STDERR.puts "FAILED TO TERMINATE DUE TO TIMEOUT"
            end
          end

        rval = mini_racer_context.eval(script)

        mutex.synchronize { done = true }

        # ensure we do not leak a thread in state
        t.join
        t = nil

        rval
      ensure
        # exceptions need to be handled
        t&.join
      end

      def invoke(progress_callback: nil)
        @progress_callback = progress_callback
        source_bindings = @secret_bindings || tool.secret_bindings
        missing_aliases = tool.missing_secret_aliases(bindings: source_bindings)
        if missing_aliases.present?
          raise ::Discourse::InvalidParameters.new(
                  I18n.t(
                    "discourse_ai.tools.secret_runtime.missing_required_aliases",
                    aliases: missing_aliases.join(", "),
                  ),
                )
        end
        preload_secrets(source_bindings)
        mini_racer_context.eval(tool.script)
        eval_with_timeout("invoke(#{JSON.generate(parameters)})")
      rescue MiniRacer::ScriptTerminatedError
        { error: "Script terminated due to timeout" }
      ensure
        @progress_callback = nil
      end

      def has_custom_context?
        mini_racer_context.eval(tool.script)
        mini_racer_context.eval("typeof customContext === 'function'")
      rescue StandardError
        false
      end

      def custom_context
        mini_racer_context.eval(tool.script)
        mini_racer_context.eval("customContext()")
      rescue StandardError
        nil
      end

      def has_custom_system_message?
        mini_racer_context.eval(tool.script)
        mini_racer_context.eval("typeof customSystemMessage === 'function'")
      rescue StandardError
        false
      end

      def custom_system_message
        mini_racer_context.eval(tool.script)
        result = eval_with_timeout("customSystemMessage()")
        return result if result.is_a?(String)
        if result.present?
          Rails.logger.warn(
            "customSystemMessage for tool #{tool.id} (#{tool.name}) returned #{result.class}, expected String",
          )
        end
        nil
      rescue StandardError => e
        Rails.logger.warn(
          "customSystemMessage failed for tool #{tool.id} (#{tool.name}): #{e.class} - #{e.message}",
        )
        nil
      end

      private

      def preload_secrets(bindings)
        secret_ids =
          bindings.filter_map do |binding|
            if binding.respond_to?(:[])
              binding[:ai_secret_id] || binding["ai_secret_id"]
            else
              binding.ai_secret_id
            end
          end
        secret_ids = secret_ids.map(&:to_i).uniq
        @secrets_cache = secret_ids.present? ? AiSecret.where(id: secret_ids).index_by(&:id) : {}
      end

      def attach_chain(mini_racer_context)
        mini_racer_context.attach("_chain_set_custom_raw", ->(raw) { self.custom_raw = raw })
        mini_racer_context.attach(
          "_chain_stream_custom_raw",
          ->(raw) do
            self.custom_raw = raw
            @progress_callback.call(raw) if @progress_callback
          end,
        )
      end

      def attach_secrets(mini_racer_context)
        mini_racer_context.attach(
          "_secrets_get",
          ->(alias_name) { in_attached_function { resolve_tool_secret!(alias_name) } },
        )
      end

      # this is useful for polling apis
      def attach_sleep(mini_racer_context)
        mini_racer_context.attach(
          "sleep",
          ->(duration_ms) do
            @sleep_calls_made += 1
            if @sleep_calls_made > MAX_SLEEP_CALLS
              raise TooManyRequestsError.new("Tool made too many sleep calls")
            end

            duration_ms = duration_ms.to_i
            if duration_ms > MAX_SLEEP_DURATION_MS
              raise ArgumentError.new(
                      "Sleep duration cannot exceed #{MAX_SLEEP_DURATION_MS}ms (1 minute)",
                    )
            end

            raise ArgumentError.new("Sleep duration must be positive") if duration_ms <= 0

            in_attached_function do
              sleep(duration_ms / 1000.0)
              { slept: duration_ms }
            end
          end,
        )
      end

      def resolve_tool_secret!(alias_name)
        value, error =
          tool.resolve_secret(
            alias_name,
            bindings: @secret_bindings || tool.secret_bindings,
            secrets_cache: @secrets_cache,
          )

        case error
        when nil
          value
        when :alias_not_declared
          raise ::Discourse::InvalidParameters.new(
                  I18n.t("discourse_ai.tools.secret_runtime.alias_not_declared", alias: alias_name),
                )
        when :missing_binding
          raise ::Discourse::InvalidParameters.new(
                  I18n.t("discourse_ai.tools.secret_runtime.missing_binding", alias: alias_name),
                )
        when :secret_not_found
          raise ::Discourse::InvalidParameters.new(
                  I18n.t("discourse_ai.tools.secret_runtime.secret_not_found", alias: alias_name),
                )
        else
          raise ::Discourse::InvalidParameters.new(
                  I18n.t("discourse_ai.tools.secret_runtime.unknown_error"),
                )
        end
      end

      def in_attached_function
        self.running_attached_function = true
        yield
      ensure
        self.running_attached_function = false
      end

      def recursive_as_json(obj)
        case obj
        when Array
          obj.map { |item| recursive_as_json(item) }
        when Hash
          obj.transform_values { |value| recursive_as_json(value) }
        when ActiveModel::Serializer, ActiveModel::ArraySerializer
          recursive_as_json(obj.as_json)
        when ActiveRecord::Base
          recursive_as_json(obj.as_json)
        else
          # Handle objects that respond to as_json but aren't handled above
          if obj.respond_to?(:as_json)
            result = obj.as_json
            if result.equal?(obj)
              # If as_json returned the same object, return it to avoid infinite recursion
              result
            else
              recursive_as_json(result)
            end
          else
            # Primitive values like strings, numbers, booleans, nil
            obj
          end
        end
      end
    end
  end
end
