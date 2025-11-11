# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class UpdateArtifact < Tool
        def self.name
          "update_artifact"
        end

        def self.signature
          {
            name: "update_artifact",
            description: "Updates an existing web artifact",
            parameters: [
              {
                name: "artifact_id",
                description: "The ID of the artifact to update",
                type: "integer",
                required: true,
              },
              {
                name: "instructions",
                description: "Clear instructions on what changes need to be made to the artifact.",
                type: "string",
                required: true,
              },
              {
                name: "version",
                description:
                  "The version number of the artifact to update, if not supplied latest version will be updated",
                type: "integer",
                required: false,
              },
            ],
          }
        end

        def self.inject_prompt(prompt:, context:, persona:)
          return if persona.options["do_not_echo_artifact"].to_s == "true"
          # we inject the current artifact content into the last user message
          if topic_id = context.topic_id
            posts = Post.where(topic_id: topic_id)
            artifact = AiArtifact.order("id desc").where(post: posts).first
            if artifact
              latest_version = artifact.versions.order(version_number: :desc).first
              current = latest_version || artifact

              artifact_source = <<~MSG
                Current Artifact:

                ### HTML
                ```html
                #{current.html}
                ```

                ### CSS
                ```css
                #{current.css}
                ```

                ### JavaScript
                ```javascript
                #{current.js}
                ```

              MSG

              last_message = prompt.messages.last
              last_message[:content] = "#{artifact_source}\n\n#{last_message[:content]}"
            end
          end
        end

        def self.accepted_options
          [
            option(:editor_llm, type: :llm),
            option(:update_algorithm, type: :enum, values: %w[diff full], default: "diff"),
            option(:do_not_echo_artifact, type: :boolean, default: true),
          ]
        end

        def self.allow_partial_tool_calls?
          true
        end

        def partial_invoke
          in_progress(instructions: parameters[:instructions]) if parameters[:instructions].present?
        end

        def in_progress(instructions:, source: nil)
          source = (<<~HTML) if source.present?
            ### Source

            ````
            #{source}
            ````
          HTML

          self.custom_raw = <<~HTML
            <details>
              <summary>Thinking...</summary>

              ### Instructions
              ````
              #{instructions}
              ````

              #{source}

            </details>
          HTML
        end

        def invoke
          post = Post.find_by(id: context.post_id)
          return error_response("No post context found") unless post

          artifact = AiArtifact.find_by(id: parameters[:artifact_id])
          return error_response("Artifact not found") unless artifact

          artifact_version = nil
          if version = parameters[:version]
            artifact_version = artifact.versions.find_by(version_number: version)
            # we could tell llm it is confused here if artifact version is not there
            # but let's just fix it transparently which saves an llm call
          end

          artifact_version ||= artifact.versions.order(version_number: :desc).first

          if artifact.post.topic.id != post.topic.id
            return error_response("Attempting to update an artifact you are not allowed to")
          end

          llm =
            (
              options[:editor_llm].present? &&
                LlmModel.find_by(id: options[:editor_llm].to_i)&.to_llm
            ) || self.llm

          strategy =
            (
              if options[:update_algorithm] == "diff"
                ArtifactUpdateStrategies::Diff
              else
                ArtifactUpdateStrategies::Full
              end
            )

          begin
            instructions = parameters[:instructions]
            partial_response = +""
            new_version =
              strategy
                .new(
                  llm: llm,
                  post: post,
                  user: post.user,
                  artifact: artifact,
                  artifact_version: artifact_version,
                  instructions: instructions,
                  cancel_manager: context.cancel_manager,
                )
                .apply do |progress|
                  partial_response << progress
                  in_progress(instructions: instructions, source: partial_response)
                  # force in progress to render
                  yield nil, true
                end

            update_custom_html(
              artifact: artifact,
              artifact_version: artifact_version,
              new_version: new_version,
            )
            success_response(artifact, new_version)
          rescue StandardError => e
            error_response(e.message)
          end
        end

        def chain_next_response?
          false
        end

        private

        def line_based_markdown_diff(before, after)
          # Split into lines
          before_lines = before.split("\n")
          after_lines = after.split("\n")

          # Use ONPDiff for line-level comparison
          diff = ONPDiff.new(before_lines, after_lines).diff

          # Build markdown output
          result = ["```diff"]

          diff.each do |line, status|
            case status
            when :common
              result << " #{line}"
            when :delete
              result << "-#{line}"
            when :add
              result << "+#{line}"
            end
          end

          result << "```"
          result.join("\n")
        end

        def update_custom_html(artifact:, artifact_version:, new_version:)
          content = []

          if new_version.change_description.present?
            content << [
              :description,
              "[details='#{I18n.t("discourse_ai.ai_artifact.change_description")}']\n\n````\n#{new_version.change_description}\n````\n\n[/details]",
            ]
          end
          content << [nil, "[details='#{I18n.t("discourse_ai.ai_artifact.view_changes")}']"]

          %w[html css js].each do |type|
            source = artifact_version || artifact
            old_content = source.public_send(type)
            new_content = new_version.public_send(type)

            if old_content != new_content
              diff = line_based_markdown_diff(old_content, new_content)
              content << [nil, "### #{type.upcase} Changes\n#{diff}"]
            end
          end

          content << [nil, "[/details]"]
          content << [
            :preview,
            "### Preview\n\n<div class=\"ai-artifact\" data-ai-artifact-version=\"#{new_version.version_number}\" data-ai-artifact-id=\"#{artifact.id}\"></div>",
          ]

          self.custom_raw = content.map { |c| c[1] }.join("\n\n")
        end

        def success_response(artifact, version)
          {
            status: "success",
            artifact_id: artifact.id,
            version: version.version_number,
            message: "Artifact updated successfully and rendered to user.",
          }
        end

        def error_response(message)
          self.custom_raw = ""
          { status: "error", error: message }
        end
      end
    end
  end
end
