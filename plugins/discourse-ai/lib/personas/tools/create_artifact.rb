# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class CreateArtifact < Tool
        def self.name
          "create_artifact"
        end

        def self.specification_description
          <<~DESC
            A detailed description of the web artifact you want to create. Your specification should include:

            1. Purpose and functionality
            2. Visual design requirements
            3. Interactive elements and behavior
            4. Data handling (if applicable)
            5. Specific requirements or constraints
            6. DO NOT include full source code of the artifact, just very clear requirements

            Good specification examples:

            Example: (Calculator):
            "Create a modern calculator with a dark theme. It should:
            - Have a large display area showing current and previous calculations
            - Include buttons for numbers 0-9, basic operations (+,-,*,/), and clear
            - Use a grid layout with subtle hover effects on buttons
            - Show button press animations
            - Keep calculation history visible above current input
            - Use a monospace font for numbers
            - Support keyboard input for numbers and operations"

            Poor specification example:
            "Make a website that looks nice and does cool stuff"
            (Too vague, lacks specific requirements and functionality details)

            Tips for good specifications:
            - Be specific about layout and design preferences
            - Describe all interactive elements and their behavior
            - Include any specific visual effects or animations
            - Mention responsive design requirements if needed
            - List any specific libraries or frameworks to use/avoid
            - Describe error states and edge cases
            - Include accessibility requirements
            - Include code snippets to help ground the specification
          DESC
        end

        def self.signature
          {
            name: "create_artifact",
            description: "Creates a web artifact based on a specification",
            parameters: [
              {
                name: "name",
                description: "A name for the artifact (max 255 chars)",
                type: "string",
                required: true,
              },
              {
                name: "specification",
                type: "string",
                description: specification_description,
                required: true,
              },
              {
                name: "requires_storage",
                description:
                  "Does the artifact require storage for data? (e.g., user input, settings)",
                type: "boolean",
                required: true,
              },
            ],
          }
        end

        def self.accepted_options
          [option(:creator_llm, type: :llm)]
        end

        def self.allow_partial_tool_calls?
          true
        end

        def partial_invoke
          if parameters[:specification].present?
            in_progress(specification: parameters[:specification])
          end
        end

        def in_progress(specification:, source: nil)
          source = (<<~HTML) if source.present?
            ### Source

            ````
            #{source}
            ````
          HTML

          self.custom_raw = <<~HTML
            <details>
              <summary>Thinking...</summary>


            ### Specification
            ````
            #{specification}
            ````

            #{source}

            </details>
          HTML
        end

        def invoke
          post = Post.find_by(id: context.post_id)
          return error_response("No post context found") unless post

          partial_response = +""
          artifact_code =
            generate_artifact_code(post: post, user: post.user) do |partial|
              partial_response << partial
              in_progress(specification: parameters[:specification], source: partial_response)
              yield nil, true
            end
          return error_response(artifact_code[:error]) if artifact_code[:error]

          artifact = create_artifact(post, artifact_code)

          if artifact.save
            update_custom_html(artifact)
            success_response(artifact)
          else
            self.custom_raw = self.custom_raw + "\n\n###Error creating artifact..."
            error_response(artifact.errors.full_messages.join(", "))
          end
        end

        def chain_next_response?
          false
        end

        def description_args
          { name: parameters[:name], specification: parameters[:specification] }
        end

        private

        def generate_artifact_code(post:, user:)
          prompt = build_artifact_prompt(post: post)
          response = +""

          llm =
            (
              options[:creator_llm].present? &&
                LlmModel.find_by(id: options[:creator_llm].to_i)&.to_llm
            ) || self.llm

          llm.generate(
            prompt,
            user: user,
            feature_name: "create_artifact",
            cancel_manager: context.cancel_manager,
          ) do |partial_response|
            response << partial_response
            yield partial_response
          end

          sections = parse_sections(response)

          if valid_sections?(sections)
            html, css, js = sections
            { html: html, css: css, js: js }
          else
            { error: "Failed to generate valid artifact code", response: response }
          end
        end

        def build_artifact_prompt(post:)
          DiscourseAi::Completions::Prompt.new(
            artifact_system_prompt,
            messages: [{ type: :user, content: parameters[:specification] }],
            post_id: post.id,
            topic_id: post.topic_id,
          )
        end

        def parse_sections(response)
          sections = { html: nil, css: nil, javascript: nil }
          current_section = nil
          lines = []

          response.each_line do |line|
            case line
            when /^\[(HTML|CSS|JavaScript)\]$/
              current_section = line.match(/^\[(.+)\]$/)[1].downcase.to_sym
              lines = []
            when %r{^\[/(HTML|CSS|JavaScript)\]$}
              sections[current_section] = lines.join if current_section
              current_section = nil
              lines = []
            else
              lines << line if current_section
            end
          end

          [sections[:html].to_s.strip, sections[:css].to_s.strip, sections[:javascript].to_s.strip]
        end

        def valid_sections?(sections)
          return false if sections.empty?

          # Basic validation of sections
          has_html = sections[0].include?("<") && sections[0].include?(">")
          has_css = sections[1].include?("{") && sections[1].include?("}")
          has_js = sections[2].present?

          has_html || has_css || has_js
        end

        def create_artifact(post, code)
          AiArtifact.new(
            user_id: bot_user.id,
            post_id: post.id,
            name: parameters[:name].to_s[0...255],
            html: code[:html],
            css: code[:css],
            js: code[:js],
            metadata: {
              specification: parameters[:specification],
              requires_storage: !!parameters[:requires_storage],
            },
          )
        end

        def artifact_system_prompt
          <<~PROMPT
            You are a web development expert creating HTML, CSS, and JavaScript code.
            Follow these instructions precisely:

            1. Provide complete source code for all three required sections: HTML, CSS, and JavaScript
            2. Use exact section tags: [HTML]/[/HTML], [CSS]/[/CSS], [JavaScript]/[/JavaScript]
            3. Format requirements:
               - HTML: No <html>, <head>, or <body> tags
               - CSS: Valid CSS rules
               - JavaScript: Clean, working code
            4. NEVER USE SHORTCUTS - generate complete code for each section. No placeholders.
            5. If you need to source ANY 3rd party libraries, use the following CDNs:
            #{AiArtifact::ALLOWED_CDN_SOURCES.join("\n")}

            6. When sourcing libraries, include them in the [HTML] section, for example: <script src="https://cdn.jsdelivr.net/...."></script>

            Required response format:

            [HTML]
            <div id="app"><!-- Your complete HTML here --></div>
            [/HTML]

            [CSS]
            #app { /* Your complete CSS here */ }
            [/CSS]

            [JavaScript]
            // Your complete JavaScript here
            [/JavaScript]

            Important:
            - All three sections are required
            - Sections must use exact tags shown above
            - Focus on simplicity and reliability
            - Include basic error handling
            - Follow accessibility guidelines
            - No explanatory text, only code

            #{storage_api}
          PROMPT
        end

        def storage_api
          return if !parameters[:requires_storage]
          self.class.storage_api
        end

        def self.storage_api
          <<~API
            ## Storage API

            Your artifact has access to a persistent key-value storage system via `window.discourseArtifact`:

            ### Methods Available:

            **get(key)**
            - Parameters: key (string) - The key to retrieve
            - Returns: Promise<string|null> - The stored value or null if not found
            - Example: `const value = await window.discourseArtifact.get('user_name');`

            **set(key, value, options)**
            - Parameters:
              - key (string) - The key to store (max 50 characters)
              - value (string) - The value to store (max 5000 characters)
              - options (object, optional) - { public: boolean } - Whether other users can read this value
            - Returns: Promise<object> - The created/updated key-value record
            - Example: `await window.discourseArtifact.set('score', '100', { public: true });`

            **delete(key)**
            - Parameters: key (string) - The key to delete
            - Returns: Promise<boolean> - true if successful
            - Example: `await window.discourseArtifact.delete('temp_data');`

            **index(filter)**
            - Parameters: filter (object, optional) - Filtering options:
              - key (string) - Filter by specific key
              - all_users (boolean) - Include other users' public values
              - keys_only (boolean) - Return only keys, not values
              - page (number) - Page number for pagination
              - per_page (number) - Items per page (max 100, default 100)
            - Returns: Promise<object> - { key_values: Array(key, value, user(username, name, avatar_template)), has_more: boolean, total_count: number }
            - Example: `const result = await window.discourseArtifact.index({ keys_only: true });`

            - avatar_template: string - URL template for user avatars, MUST replace {size} with desired size in pixels (eg: 22)

            ### User info:

            To get current user info:
            const initData = await window.discourseArtifactReady;
            initData.username; // current username
            initData.name; // current user's name
            initData.user_id; // current user ID

            ### Storage Rules:
            - Each user can store up to 100 keys per artifact
            - Keys are scoped to the current user and artifact
            - Private values are only accessible to the user who created them
            - Public values can be read by anyone who can view the artifact
            - All operations are asynchronous and return Promises
            ```
          API
        end

        def update_custom_html(artifact)
          html_preview = <<~MD
            [details="View Source"]
            ### HTML
            ```html
            #{artifact.html}
            ```

            ### CSS
            ```css
            #{artifact.css}
            ```

            ### JavaScript
            ```javascript
            #{artifact.js}
            ```
            [/details]

            ### Preview
            <div class="ai-artifact" data-ai-artifact-id="#{artifact.id}"></div>
          MD

          self.custom_raw = html_preview
        end

        def success_response(artifact)
          { status: "success", artifact_id: artifact.id, message: "Artifact created successfully." }
        end

        def error_response(message)
          { status: "error", error: message }
        end
      end
    end
  end
end
