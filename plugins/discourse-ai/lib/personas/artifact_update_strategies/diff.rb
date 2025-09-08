# frozen_string_literal: true
module DiscourseAi
  module Personas
    module ArtifactUpdateStrategies
      class Diff < Base
        attr_reader :failed_searches

        private

        def initialize(**kwargs)
          super
          @failed_searches = []
        end

        def build_prompt
          DiscourseAi::Completions::Prompt.new(
            system_prompt,
            messages: [{ type: :user, content: user_prompt }],
            post_id: post.id,
            topic_id: post.topic_id,
          )
        end

        def parse_changes(response)
          sections = { html: nil, css: nil, javascript: nil }
          current_section = nil
          lines = []

          response.each_line do |line|
            case line
            when /^\[(HTML|CSS|JavaScript)\]$/
              sections[current_section] = lines.join if current_section && !lines.empty?
              current_section = line.match(/^\[(.+)\]$/)[1].downcase.to_sym
              lines = []
            when %r{^\[/(?:HTML|CSS|JavaScript)\]$}
              sections[current_section] = lines.join if current_section && !lines.empty?
              current_section = nil
            else
              lines << line if current_section
            end
          end

          sections.each do |section, content|
            sections[section] = extract_search_replace_blocks(content)
          end

          sections
        end

        def apply_changes(changes)
          source = artifact_version || artifact
          updated_content = { js: source.js, html: source.html, css: source.css }

          %i[html css javascript].each do |section|
            blocks = changes[section]
            next unless blocks

            content = source.public_send(section == :javascript ? :js : section)
            blocks.each do |block|
              begin
                if !block[:search]
                  content = block[:replace]
                else
                  content =
                    DiscourseAi::Utils::DiffUtils::SimpleDiff.apply(
                      content,
                      block[:search],
                      block[:replace],
                    )
                end
              rescue DiscourseAi::Utils::DiffUtils::SimpleDiff::NoMatchError
                @failed_searches << { section: section, search: block[:search] }
                # TODO, we may need to inform caller here, LLM made a mistake which it
                # should correct
                puts "Failed to find search: #{block[:search]}"
              end
            end
            updated_content[section == :javascript ? :js : section] = content
          end

          artifact.create_new_version(
            html: updated_content[:html],
            css: updated_content[:css],
            js: updated_content[:js],
            change_description: instructions,
          )
        end

        private

        def extract_search_replace_blocks(content)
          return nil if content.blank? || content.to_s.strip.downcase.match?(/^\(?no changes?\)?$/m)
          return [{ replace: content }] if !content.include?("<<< SEARCH")

          blocks = []
          current_block = {}
          state = :initial
          search_lines = []
          replace_lines = []

          content.each_line do |line|
            line = line.chomp

            case state
            when :initial
              state = :collecting_search if line.match?(/^<<<* SEARCH/)
            when :collecting_search
              if line.start_with?("===")
                current_block[:search] = search_lines.join("\n").strip
                search_lines = []
                state = :collecting_replace
              else
                search_lines << line
              end
            when :collecting_replace
              if line.match?(/>>>* REPLACE/)
                current_block[:replace] = replace_lines.join("\n").strip
                replace_lines = []
                blocks << current_block
                current_block = {}
                state = :initial
              else
                replace_lines << line
              end
            end
          end

          # Handle any remaining block
          if state == :collecting_replace && !replace_lines.empty?
            current_block[:replace] = replace_lines.join("\n").strip
            blocks << current_block
          end

          blocks.empty? ? nil : blocks
        end

        def system_prompt
          <<~PROMPT
            You are a web development expert generating precise search/replace changes for updating HTML, CSS, and JavaScript code.

            CRITICAL RULES:

            1. Use EXACTLY this format for changes:
               <<<<<<< SEARCH
               (code to replace)
               =======
               (replacement code)
               >>>>>>> REPLACE

            2. SEARCH blocks MUST be 8 lines or less. Break larger changes into multiple smaller search/replace blocks.

            3. DO NOT modify the markers or add spaces around them.

            4. DO NOT add explanations or comments within sections.

            5. ONLY include [HTML], [CSS], and [JavaScript] sections if they have changes.

            6. HTML should not include <html>, <head>, or <body> tags, it is injected into a template.

            7. NEVER EVER ask followup questions, ALL changes must be performed in a single response.

            8. When performing a non-contiguous search, ALWAYS use ... to denote the skipped lines.

            9. Be mindful that ... non-contiguous search is not greedy, it will only match the first occurrence.

            10. Never mix a full section replacement with a search/replace block in the same section.

            11. ALWAYS skip sections you do not want to change, do not include them in the response.

            HANDLING LARGE CHANGES:

            - Break large HTML structures into multiple smaller search/replace blocks.
            - Use strategic anchor points like unique IDs or class names to target specific elements.
            - Consider replacing entire components rather than modifying complex internals.
            - When elements contain dynamic content, use precise context markers or replace entire containers.

            VALIDATION CHECKLIST:
            - Each SEARCH block is 8 lines or less
            - Every SEARCH has exactly one matching REPLACE
            - All blocks are properly closed
            - No SEARCH/REPLACE blocks are nested
            - Each change is a complete, separate block with its own SEARCH/REPLACE markers

            WARNING: Never nest search/replace blocks. Each change must be a complete sequence.

            JavaScript libraries must be sourced from the following CDNs, otherwise CSP will reject it:
            #{AiArtifact::ALLOWED_CDN_SOURCES.join("\n")}

            #{storage_api}

            Reply Format:
            [HTML]
            (changes or empty if no changes or entire HTML)
            [/HTML]
            [CSS]
            (changes or empty if no changes or entire CSS)
            [/CSS]
            [JavaScript]
            (changes or empty if no changes or entire JavaScript)
            [/JavaScript]

            EXAMPLE 1 - Multiple small changes in one file:

            [JavaScript]
            <<<<<<< SEARCH
            console.log('old1');
            =======
            console.log('new1');
            >>>>>>> REPLACE
            <<<<<<< SEARCH
            console.log('old2');
            =======
            console.log('new2');
            >>>>>>> REPLACE
            [/JavaScript]

            EXAMPLE 2 - Breaking up large HTML changes:

            [HTML]
            <<<<<<< SEARCH
            <div class="header">
              <div class="logo">
                <img src="old-logo.png">
              </div>
            =======
            <div class="header">
              <div class="logo">
                <img src="new-logo.png">
              </div>
            >>>>>>> REPLACE

            <<<<<<< SEARCH
              <div class="navigation">
                <ul>
                  <li>Home</li>
                  <li>Products</li>
            =======
              <div class="navigation">
                <ul>
                  <li>Home</li>
                  <li>Services</li>
            >>>>>>> REPLACE
            [/HTML]

            EXAMPLE 3 - Non-contiguous search in CSS:

            [CSS]
            <<<<<<< SEARCH
            body {
            ...
              background-color: green;
            }
            =======
            body {
              color: red;
            }
            >>>>>>> REPLACE
            [/CSS]

            EXAMPLE 4 - Full HTML replacement:

            [HTML]
            <div>something old</div>
            <div>another something old</div>
            [/HTML]

            output:

            [HTML]
            <div>something new</div>
            [/HTML]
          PROMPT
        end

        def user_prompt
          source = artifact_version || artifact
          <<~CONTENT
            Artifact code:

            [HTML]
            #{source.html}
            [/HTML]

            [CSS]
            #{source.css}
            [/CSS]

            [JavaScript]
            #{source.js}
            [/JavaScript]

            Instructions:

            #{instructions}
          CONTENT
        end
      end
    end
  end
end
