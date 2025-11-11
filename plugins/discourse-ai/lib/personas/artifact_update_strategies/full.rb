# frozen_string_literal: true
module DiscourseAi
  module Personas
    module ArtifactUpdateStrategies
      class Full < Base
        private

        def build_prompt
          DiscourseAi::Completions::Prompt.new(
            system_prompt,
            messages: [
              { type: :user, content: "#{current_artifact_content}\n\n\n#{instructions}" },
            ],
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
            when %r{^\[/(HTML|CSS|JavaScript)\]$}
              sections[current_section] = lines.join if current_section && !lines.empty?
              current_section = nil
              lines = []
            else
              lines << line if current_section
            end
          end

          sections
        end

        def apply_changes(changes)
          source = artifact_version || artifact
          updated_content = { js: source.js, html: source.html, css: source.css }

          %i[html css javascript].each do |section|
            content = changes[section]&.strip
            next if content.blank?
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

        def system_prompt
          <<~PROMPT
            You are a web development expert generating updated HTML, CSS, and JavaScript code.

            Important rules:
            1. Provide full source code for each changed section
            2. Generate up to three sections: HTML, CSS, and JavaScript
            3. Only include sections that need changes
            4. Keep changes focused on the requirements
            5. NEVER EVER BE LAZY, always include ALL the source code with any update you make. If you are lazy you will break the artifact.
            6. Do not print out any reasoning, just the changed code, you will be parsed via a program.
            7. Sections must start and end with exact tags: [HTML] [/HTML], [CSS] [/CSS], [JavaScript] [/JavaScript]
            8. HTML should not include <html>, <head>, or <body> tags, it is injected into a template

            JavaScript libraries must be sourced from the following CDNs, otherwise CSP will reject it:
            #{AiArtifact::ALLOWED_CDN_SOURCES.join("\n")}

            #{storage_api}

            Always adhere to the format when replying:

            [HTML]
            complete html code, omit if no changes
            [/HTML]

            [CSS]
            complete css code, omit if no changes
            [/CSS]

            [JavaScript]
            complete js code, omit if no changes
            [/JavaScript]

            Examples:

            Example 1 (HTML only change):
            [HTML]
            <div class="container">
              <h1>Title</h1>
            </div>
            [/HTML]

            Example 2 (CSS and JavaScript changes):
            [CSS]
            .container { padding: 20px; }
            .title { color: blue; }
            [/CSS]
            [JavaScript]
            function init() {
              console.log("loaded");
            }
            [/JavaScript]

            Example 3 (All sections):
            [HTML]
            <div id="app"></div>
            [/HTML]
            [CSS]
            #app { margin: 0; }
            [/CSS]
            [JavaScript]
            const app = document.getElementById("app");
            [/JavaScript]

          PROMPT
        end

        def current_artifact_content
          source = artifact_version || artifact
          <<~CONTENT
            Current artifact code:

            [HTML]
            #{source.html}
            [/HTML]

            [CSS]
            #{source.css}
            [/CSS]

            [JavaScript]
            #{source.js}
            [/JavaScript]
          CONTENT
        end
      end
    end
  end
end
