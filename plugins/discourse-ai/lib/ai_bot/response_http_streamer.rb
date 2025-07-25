# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ResponseHttpStreamer
      CRLF = "\r\n"
      POOL_SIZE = 10

      class << self
        def thread_pool
          # we use our thread pool implementation here for a few reasons:
          #
          # 1. Free multisite support
          # 2. Unlike Concurrent::CachedThreadPool, we spin back down to 0 threads automatiaclly see: https://github.com/ruby-concurrency/concurrent-ruby/issues/1075
          # 3. Better internal error handling
          @thread_pool ||=
            Scheduler::ThreadPool.new(min_threads: 0, max_threads: POOL_SIZE, idle_time: 30)
        end

        def schedule_block(&block)
          thread_pool.post do
            begin
              block.call
            rescue StandardError => e
              Discourse.warn_exception(e, message: "Discourse AI: Unable to stream reply")
            end
          end
        end

        # keeping this in a static method so we don't capture ENV and other bits
        # this allows us to release memory earlier
        def queue_streamed_reply(
          io:,
          persona:,
          user:,
          topic:,
          query:,
          custom_instructions:,
          current_user:
        )
          schedule_block do
            begin
              post_params = {
                raw: query,
                skip_validations: true,
                custom_fields: {
                  DiscourseAi::AiBot::Playground::BYPASS_AI_REPLY_CUSTOM_FIELD => true,
                },
              }

              if topic
                post_params[:topic_id] = topic.id
              else
                post_params[:title] = I18n.t("discourse_ai.ai_bot.default_pm_prefix")
                post_params[:archetype] = Archetype.private_message
                post_params[:target_usernames] = "#{user.username},#{persona.user.username}"
              end

              post = PostCreator.create!(user, post_params)
              topic = post.topic

              io.write "HTTP/1.1 200 OK"
              io.write CRLF
              io.write "Content-Type: text/plain; charset=utf-8"
              io.write CRLF
              io.write "Transfer-Encoding: chunked"
              io.write CRLF
              io.write "Cache-Control: no-cache, no-store, must-revalidate"
              io.write CRLF
              io.write "Connection: close"
              io.write CRLF
              io.write "X-Accel-Buffering: no"
              io.write CRLF
              io.write "X-Content-Type-Options: nosniff"
              io.write CRLF
              io.write CRLF
              io.flush

              persona_class =
                DiscourseAi::Personas::Persona.find_by(id: persona.id, user: current_user)
              bot = DiscourseAi::Personas::Bot.as(persona.user, persona: persona_class.new)

              data =
                {
                  topic_id: topic.id,
                  bot_user_id: persona.user.id,
                  persona_id: persona.id,
                }.to_json + "\n\n"

              io.write data.bytesize.to_s(16)
              io.write CRLF
              io.write data
              io.write CRLF

              DiscourseAi::AiBot::Playground
                .new(bot)
                .reply_to(post, custom_instructions: custom_instructions) do |partial|
                  next if partial.length == 0

                  data = { partial: partial }.to_json + "\n\n"

                  data.force_encoding("UTF-8")

                  io.write data.bytesize.to_s(16)
                  io.write CRLF
                  io.write data
                  io.write CRLF
                  io.flush
                end

              io.write "0"
              io.write CRLF
              io.write CRLF

              io.flush
              io.done if io.respond_to?(:done)
            rescue StandardError => e
              # make it a tiny bit easier to debug in dev, this is tricky
              # multi-threaded code that exhibits various limitations in rails
              p e if Rails.env.development? || Rails.env.test?
              Discourse.warn_exception(e, message: "Discourse AI: Unable to stream reply")
            ensure
              io.close
            end
          end
        end
      end
    end
  end
end
