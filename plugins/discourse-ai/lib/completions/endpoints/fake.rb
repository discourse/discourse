# frozen_string_literal: true

module DiscourseAi
  module Completions
    module Endpoints
      class Fake < Base
        STOCK_CONTENT = <<~TEXT
      # Discourse Markdown Styles Showcase

      Welcome to the **Discourse Markdown Styles Showcase**! This _post_ is designed to demonstrate a wide range of Markdown capabilities available in Discourse.

      ## Lists and Emphasis

      - **Bold Text**: To emphasize a point, you can use bold text.
      - _Italic Text_: To subtly highlight text, italics are perfect.
      - ~~Strikethrough~~: Sometimes, marking text as obsolete requires a strikethrough.

      > **Note**: Combining these _styles_ can **_really_** make your text stand out!

      1. First item
      2. Second item
          * Nested bullet
          * Another nested bullet
      3. Third item

      ## Links and Images

      You can easily add [links](https://meta.discourse.org) to your posts. For adding images, use this syntax:

      ![Discourse Logo](https://meta.discourse.org/images/discourse-logo.svg)

      ## Code and Quotes

      Inline `code` is used for mentioning small code snippets like `let x = 10;`. For larger blocks of code, fenced code blocks are used:

      ```javascript
      function greet() {
          console.log("Hello, Discourse Community!");
      }
      greet();
      ```

      > Blockquotes can be very effective for highlighting user comments or important sections from cited sources. They stand out visually and offer great readability.

      ## Tables and Horizontal Rules

      Creating tables in Markdown is straightforward:

      | Header 1 | Header 2 | Header 3 |
      | ---------|:--------:| --------:|
      | Row 1, Col 1 | Centered | Right-aligned |
      | Row 2, Col 1 | **Bold** | _Italic_ |
      | Row 3, Col 1 | `Inline Code` | [Link](https://meta.discourse.org) |

      To separate content sections:

      ---

      ## Final Thoughts

      Congratulations, you've now seen a small sample of what Discourse's Markdown can do! For more intricate formatting, consider exploring the advanced styling options. Remember that the key to great formatting is not just the available tools, but also the **clarity** and **readability** it brings to your readers.
    TEXT

        def self.can_contact?(model_provider)
          model_provider == "fake"
        end

        def self.with_fake_content(content)
          @fake_content = content
          yield
        ensure
          @fake_content = nil
        end

        def self.fake_content=(content)
          @fake_content = content
        end

        def self.fake_content
          @fake_content || STOCK_CONTENT
        end

        def self.delays
          @delays ||= Array.new(10) { Rails.env.test? ? 0 : rand(0..5) }
        end

        def self.delays=(delays)
          @delays = delays
        end

        def self.chunk_count
          @chunk_count ||= 10
        end

        def self.chunk_count=(chunk_count)
          @chunk_count = chunk_count
        end

        def self.last_call
          @last_call
        end

        def self.last_call=(params)
          @last_call = params
        end

        def self.previous_calls
          @previous_calls ||= []
        end

        def self.reset!
          @last_call = nil
          @fake_content = nil
          @delays = nil
          @chunk_count = nil
        end

        def perform_completion!(
          dialect,
          user,
          model_params = {},
          feature_name: nil,
          feature_context: nil,
          partial_tool_calls: false,
          output_thinking: false,
          cancel_manager: nil
        )
          last_call = { dialect: dialect, user: user, model_params: model_params }
          self.class.last_call = last_call
          self.class.previous_calls << last_call
          # guard memory in test
          self.class.previous_calls.shift if self.class.previous_calls.length > 10

          content = self.class.fake_content

          content = content.shift if content.is_a?(Array)

          if block_given?
            if content.is_a?(DiscourseAi::Completions::ToolCall)
              yield(content, -> {})
            else
              split_indices = (1...content.length).to_a.sample(self.class.chunk_count - 1).sort
              indexes = [0, *split_indices, content.length]

              original_content = content
              content = +""

              cancel = false
              cancel_proc = -> { cancel = true }

              i = 0
              indexes
                .each_cons(2)
                .map { |start, finish| original_content[start...finish] }
                .each do |chunk|
                  break if cancel
                  if self.class.delays.present? &&
                       (delay = self.class.delays[i % self.class.delays.length])
                    sleep(delay)
                    i += 1
                  end
                  break if cancel

                  content << chunk
                  yield(chunk, cancel_proc)
                end
            end
          end

          content
        end
      end
    end
  end
end
