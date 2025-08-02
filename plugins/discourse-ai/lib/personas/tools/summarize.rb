#frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class Summarize < Tool
        def self.signature
          {
            name: name,
            description: "Will summarize a topic attempting to answer question in guidance",
            parameters: [
              {
                name: "topic_id",
                description: "The discourse topic id to summarize",
                type: "integer",
                required: true,
              },
              {
                name: "guidance",
                description: "Special guidance on how to summarize the topic",
                type: "string",
              },
            ],
          }
        end

        def self.name
          "summary"
        end

        def topic_id
          parameters[:topic_id].to_i
        end

        def guidance
          parameters[:guidance]
        end

        def chain_next_response?
          false
        end

        def custom_raw
          @last_summary || I18n.t("discourse_ai.ai_bot.topic_not_found")
        end

        def invoke(&progress_blk)
          topic = nil
          if topic_id > 0
            topic = Topic.find_by(id: topic_id)
            topic = nil if !topic || !Guardian.new.can_see?(topic)
          end

          @last_summary = nil

          if topic
            @last_topic_title = topic.title

            posts =
              Post
                .where(topic_id: topic.id)
                .where("post_type in (?)", [Post.types[:regular], Post.types[:small_action]])
                .where("not hidden")
                .order(:post_number)

            columns = ["posts.id", :post_number, :raw, :username]

            current_post_numbers = posts.limit(5).pluck(:post_number)
            current_post_numbers += posts.reorder("posts.score desc").limit(50).pluck(:post_number)
            current_post_numbers += posts.reorder("post_number desc").limit(5).pluck(:post_number)

            data =
              Post
                .where(topic_id: topic.id)
                .joins(:user)
                .where("post_number in (?)", current_post_numbers)
                .order(:post_number)
                .pluck(*columns)

            @last_summary = summarize(data, topic, guidance, bot_user, llm, &progress_blk)
          end

          if !@last_summary
            "Say: No topic found!"
          else
            "Topic summarized"
          end
        end

        protected

        def description_args
          { url: "#{Discourse.base_path}/t/-/#{@last_topic_id}", title: @last_topic_title || "" }
        end

        private

        def summarize(data, topic, guidance, bot_user, llm, &progress_blk)
          text = +""
          data.each do |id, post_number, raw, username|
            text << "(#{post_number} #{username} said: #{raw}"
          end

          summaries = []
          current_section = +""
          split = []

          text
            .split(/\s+/)
            .each_slice(20) do |slice|
              current_section << " "
              current_section << slice.join(" ")

              # somehow any more will get closer to limits
              if llm.tokenizer.tokenize(current_section).length > 2500
                split << current_section
                current_section = +""
              end
            end

          split << current_section if current_section.present?

          split = split[0..3] + split[-3..-1] if split.length > 5

          progress = +I18n.t("discourse_ai.ai_bot.summarizing")
          progress_blk.call(progress)

          split.each do |section|
            progress << "."
            progress_blk.call(progress)

            prompt = section_prompt(topic, section, guidance)

            summary =
              llm.generate(
                prompt,
                temperature: 0.6,
                max_tokens: 400,
                user: bot_user,
                feature_name: "summarize_tool",
              )

            summaries << summary
          end

          if summaries.length > 1
            progress << "."
            progress_blk.call(progress)

            concatenation_prompt = {
              insts: "You are a helpful bot",
              input:
                "concatenated the disjoint summaries, creating a cohesive narrative:\n#{summaries.join("\n")}}",
            }

            llm.generate(
              concatenation_prompt,
              temperature: 0.6,
              max_tokens: 500,
              user: bot_user,
              feature_name: "summarize_tool",
            )
          else
            summaries.first
          end
        end

        def section_prompt(topic, text, guidance)
          system_prompt = <<~TEXT
          You are a summarization bot.
          You effectively summarise any text.
          You condense it into a shorter version.
          You understand and generate Discourse forum markdown.
          Try generating links as well the format is #{topic.url}/POST_NUMBER. eg: [ref](#{topic.url}/77)
          TEXT

          user_prompt = <<~TEXT
            Guidance: #{guidance}
            You are summarizing the topic: #{topic.title}
            Summarize the following in 400 words:

            #{text}
          TEXT

          messages = [{ type: :user, content: user_prompt }]
          DiscourseAi::Completions::Prompt.new(system_prompt, messages: messages)
        end
      end
    end
  end
end
