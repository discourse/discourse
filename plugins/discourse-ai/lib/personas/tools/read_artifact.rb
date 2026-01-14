# frozen_string_literal: true

module DiscourseAi
  module Personas
    module Tools
      class ReadArtifact < Tool
        MAX_HTML_SIZE = 30.kilobytes
        MAX_CSS_FILES = 5

        def self.name
          "read_artifact"
        end

        def self.signature
          {
            name: "read_artifact",
            description: "Read an artifact from a URL and convert to a local artifact",
            parameters: [
              {
                name: "url",
                type: "string",
                description: "URL of the artifact to read",
                required: true,
              },
            ],
          }
        end

        def invoke
          return error_response("Unknown context, feature only works in PMs") if !post

          uri = URI.parse(parameters[:url])
          return error_response("Invalid URL") unless uri.is_a?(URI::HTTP)

          if discourse_artifact?(uri)
            handle_discourse_artifact(uri)
          else
            handle_external_page(uri)
          end
        end

        def chain_next_response?
          @chain_next_response
        end

        private

        def error_response(message)
          @chain_next_response = true
          { status: "error", error: message }
        end

        def success_response(artifact)
          { status: "success", artifact_id: artifact.id, message: "Artifact created successfully." }
        end

        def discourse_artifact?(uri)
          uri.path.include?("/discourse-ai/ai-bot/artifacts/")
        end

        def post
          @post ||= Post.find_by(id: context.post_id)
        end

        def handle_discourse_artifact(uri)
          if uri.path =~ %r{/discourse-ai/ai-bot/artifacts/(\d+)(?:/(\d+))?}
            artifact_id = $1.to_i
            version = $2&.to_i
          else
            return error_response("Invalid artifact URL format")
          end

          if uri.host == Discourse.current_hostname
            source_artifact = AiArtifact.find_by(id: artifact_id)
            return error_response("Artifact not found") if !source_artifact

            if !source_artifact.public? && !Guardian.new(post.user).can_see?(source_artifact.post)
              return error_response("Access denied")
            end
            new_artifact = clone_artifact(source_artifact, version)
          else
            response = fetch_page(uri)
            return error_response("Failed to fetch artifact") unless response

            html, css, js = extract_discourse_artifact(response.body)
            return error_response("Invalid artifact format") unless html

            new_artifact =
              create_artifact_from_web(
                html: html,
                css: css,
                js: js,
                name: "Imported Discourse Artifact",
              )
          end

          if new_artifact&.persisted?
            update_custom_html(new_artifact)
            success_response(new_artifact)
          else
            error_response(
              new_artifact&.errors&.full_messages&.join(", ") || "Failed to create artifact",
            )
          end
        end

        def extract_discourse_artifact(html)
          doc = Nokogiri.HTML(html)
          iframe = doc.at_css("body > iframe")
          return nil unless iframe

          # parse srcdoc attribute of iframe
          iframe_doc = Nokogiri.HTML(iframe["srcdoc"])
          return nil unless iframe_doc

          body = iframe_doc.at_css("body")
          last_script_tag = body&.at_css("script:last-of-type")
          script = last_script_tag&.content.to_s[0...MAX_HTML_SIZE]
          last_script_tag.remove if last_script_tag
          content = body&.inner_html.to_s[0...MAX_HTML_SIZE]
          style = iframe_doc.at_css("style")&.content.to_s[0...MAX_HTML_SIZE]

          [content, style, script]
        end

        def handle_external_page(uri)
          response = fetch_page(uri)
          return error_response("Failed to fetch page") unless response

          html, css, js = extract_content(response, uri)
          new_artifact =
            create_artifact_from_web(html: html, css: css, js: js, name: "external artifact")

          if new_artifact&.persisted?
            update_custom_html(new_artifact)
            success_response(new_artifact)
          else
            error_response(
              new_artifact&.errors&.full_messages&.join(", ") || "Failed to create artifact",
            )
          end
        end

        def extract_content(response, uri)
          doc = Nokogiri.HTML(response.body)

          html = doc.at_css("body").to_html.to_s[0...MAX_HTML_SIZE]

          css_files =
            doc
              .css('link[rel="stylesheet"]')
              .map { |link| URI.join(uri, link["href"]).to_s }
              .first(MAX_CSS_FILES)
          css = download_css_files(css_files).to_s[0...MAX_HTML_SIZE]

          js = doc.css("script:not([src])").map(&:content).join("\n").to_s[0...MAX_HTML_SIZE]

          [html, css, js]
        end

        def clone_artifact(source, version = nil)
          source_version = version ? source.versions.find_by(version_number: version) : nil
          content = source_version || source

          AiArtifact.create!(
            user: post.user,
            post: post,
            name: source.name,
            html: content.html,
            css: content.css,
            js: content.js,
            metadata: {
              cloned_from: source.id,
              cloned_version: source_version&.version_number,
            },
          )
        end

        def create_artifact_from_web(html:, css:, js:, name:)
          AiArtifact.create(
            user: post.user,
            post: post,
            name: name,
            html: html,
            css: css,
            js: js,
            metadata: {
              imported_from: parameters[:url],
            },
          )
        end

        def update_custom_html(artifact)
          self.custom_raw = <<~HTML
            ### Artifact created successfully

            <div class="ai-artifact" data-ai-artifact-id="#{artifact.id}"></div>
          HTML
        end

        def fetch_page(uri)
          send_http_request(uri.to_s) { |response| response if response.code == "200" }
        end

        def download_css_files(urls)
          urls.map { |url| fetch_page(URI.parse(url)).body }.join("\n")
        end
      end
    end
  end
end
