# frozen_string_literal: true

module DiscourseAi
  module Utils
    module Research
      class LlmFormatter
        def initialize(filter, max_tokens_per_batch:, tokenizer:, max_tokens_per_post:)
          @filter = filter
          @max_tokens_per_batch = max_tokens_per_batch
          @tokenizer = tokenizer
          @max_tokens_per_post = max_tokens_per_post
          @to_process = filter_to_hash
        end

        def each_chunk
          return nil if @to_process.empty?

          result = { post_count: 0, topic_count: 0, text: +"" }
          estimated_tokens = 0

          @to_process.each do |topic_id, topic_data|
            topic = Topic.find_by(id: topic_id)
            next unless topic

            topic_text, topic_tokens, post_count = format_topic(topic, topic_data[:posts])

            # If this single topic exceeds our token limit and we haven't added anything yet,
            # we need to include at least this one topic (partial content)
            if estimated_tokens == 0 && topic_tokens > @max_tokens_per_batch
              offset = 0
              while offset < topic_text.length
                chunk = +""
                chunk_tokens = 0
                lines = topic_text[offset..].lines
                lines.each do |line|
                  line_tokens = estimate_tokens(line)
                  break if chunk_tokens + line_tokens > @max_tokens_per_batch
                  chunk << line
                  chunk_tokens += line_tokens
                end
                break if chunk.empty?
                yield(
                  {
                    text: chunk,
                    post_count: post_count, # This may overcount if split mid-topic, but preserves original logic
                    topic_count: 1,
                  }
                )
                offset += chunk.length
              end

              next
            end

            # If adding this topic would exceed our token limit and we already have content, skip it
            if estimated_tokens > 0 && estimated_tokens + topic_tokens > @max_tokens_per_batch
              yield result if result[:text].present?
              estimated_tokens = 0
              result = { post_count: 0, topic_count: 0, text: +"" }
            else
              # Add this topic to the result
              result[:text] << topic_text
              result[:post_count] += post_count
              result[:topic_count] += 1
              estimated_tokens += topic_tokens
            end
          end
          yield result if result[:text].present?

          @to_process.clear
        end

        private

        def filter_to_hash
          hash = {}
          @filter
            .search
            .pluck(:topic_id, :id, :post_number)
            .each do |topic_id, post_id, post_number|
              hash[topic_id] ||= { posts: [] }
              hash[topic_id][:posts] << [post_id, post_number]
            end

          hash.each_value { |topic| topic[:posts].sort_by! { |_, post_number| post_number } }
          hash
        end

        def format_topic(topic, posts_data)
          text = ""
          total_tokens = 0
          post_count = 0

          # Add topic header
          text += format_topic_header(topic)
          total_tokens += estimate_tokens(text)

          # Get all post numbers in this topic
          all_post_numbers = topic.posts.pluck(:post_number).sort

          # Format posts with omitted information
          first_post_number = posts_data.first[1]
          last_post_number = posts_data.last[1]

          # Handle posts before our selection
          if first_post_number > 1
            omitted_before = first_post_number - 1
            text += format_omitted_posts(omitted_before, "before")
            total_tokens += estimate_tokens(format_omitted_posts(omitted_before, "before"))
          end

          # Format each post
          posts_data.each do |post_id, post_number|
            post = Post.find_by(id: post_id)
            next unless post

            text += format_post(post)
            total_tokens += estimate_tokens(format_post(post))
            post_count += 1
          end

          # Handle posts after our selection
          if last_post_number < all_post_numbers.last
            omitted_after = all_post_numbers.last - last_post_number
            text += format_omitted_posts(omitted_after, "after")
            total_tokens += estimate_tokens(format_omitted_posts(omitted_after, "after"))
          end

          [text, total_tokens, post_count]
        end

        def format_topic_header(topic)
          header = +"# #{topic.title}\n"

          # Add category
          header << "Category: #{topic.category.name}\n" if topic.category

          # Add tags
          header << "Tags: #{topic.tags.map(&:name).join(", ")}\n" if topic.tags.present?

          # Add creation date
          header << "Created: #{format_date(topic.created_at)}\n"
          header << "Topic url: /t/#{topic.id}\n"
          header << "Status: #{format_topic_status(topic)}\n\n"

          header
        end

        def format_topic_status(topic)
          solved = topic.respond_to?(:solved) && topic.solved.present?
          solved_text = solved ? " (solved)" : ""
          if topic.archived?
            "Archived#{solved_text}"
          elsif topic.closed?
            "Closed#{solved_text}"
          else
            "Open#{solved_text}"
          end
        end

        def format_post(post)
          text = +"---\n"
          text << "## Post by #{post.user&.username} - #{format_date(post.created_at)}\n\n"
          text << "#{truncate_if_needed(post.raw)}\n"
          text << "Likes: #{post.like_count}\n" if post.like_count.to_i > 0
          text << "Post url: /t/-/#{post.topic_id}/#{post.post_number}\n\n"
          text
        end

        def truncate_if_needed(content)
          tokens_count = estimate_tokens(content)

          return content if tokens_count <= @max_tokens_per_post

          half_limit = @max_tokens_per_post / 2
          token_ids = @tokenizer.encode(content)

          first_half_ids = token_ids[0...half_limit]
          last_half_ids = token_ids[-half_limit..-1]

          first_text = @tokenizer.decode(first_half_ids)
          last_text = @tokenizer.decode(last_half_ids)

          "#{first_text}\n\n... elided #{tokens_count - @max_tokens_per_post} tokens ...\n\n#{last_text}"
        end

        def format_omitted_posts(count, position)
          if position == "before"
            "#{count} earlier #{count == 1 ? "post" : "posts"} omitted\n\n"
          else
            "#{count} later #{count == 1 ? "post" : "posts"} omitted\n\n"
          end
        end

        def format_date(date)
          date.strftime("%Y-%m-%d %H:%M")
        end

        def estimate_tokens(text)
          @tokenizer.tokenize(text).length
        end
      end
    end
  end
end
