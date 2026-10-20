# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactsController < ApplicationController
      requires_plugin PLUGIN_NAME
      before_action :require_site_settings!

      skip_before_action :preload_json, :check_xhr, only: %i[show shared embed forum]
      skip_after_action :set_cross_origin_opener_policy_header, only: %i[show shared embed forum]

      def embed
        raise Discourse::NotFound if !params[:id].to_s.match?(/\A[1-9]\d*\z/)

        artifact = AiArtifact.find(params[:id])
        raise Discourse::NotFound if !artifact.publicly_embeddable?

        version = nil
        if params[:version].present?
          raise Discourse::NotFound if !params[:version].to_s.match?(/\A[1-9]\d*\z/)

          version = artifact.versions.find_by(version_number: params[:version])
          raise Discourse::NotFound if !version
        end

        untrusted_html = build_untrusted_html(version || artifact, artifact.name, standalone: true)
        trusted_html = build_trusted_html(nil, nil, artifact.name, untrusted_html, standalone: true)

        set_security_headers
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        render html: trusted_html.html_safe, layout: false, content_type: "text/html"
      end

      def shared
        share = find_public_share
        untrusted_html = build_untrusted_html(share, share.name, standalone: true)
        trusted_html = build_trusted_html(nil, nil, share.name, untrusted_html, standalone: true)

        set_security_headers
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        render html: trusted_html.html_safe, layout: false, content_type: "text/html"
      end

      def forum
        share = find_public_share
        untrusted_html = build_untrusted_html(share, share.name)
        trusted_html = build_trusted_html(share, nil, share.name, untrusted_html)

        set_native_security_headers
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        render html: trusted_html.html_safe, layout: false, content_type: "text/html"
      end

      def shared_metadata
        render_metadata(find_public_share.name)
      end

      def metadata
        id = params[:id].to_s
        if !id.match?(/\A[1-9]\d{0,18}\z/) || id.to_i > 9_223_372_036_854_775_807
          raise Discourse::NotFound
        end

        artifact = AiArtifact.find_by(id: id)
        raise Discourse::NotFound if !artifact&.available_to?(guardian)

        if params.key?(:version)
          version = params[:version].to_s
          if !version.match?(/\A(?:0|[1-9]\d{0,9})\z/) || version.to_i > 2_147_483_647
            raise Discourse::NotFound
          end
          if version != "0" && !artifact.versions.exists?(version_number: version.to_i)
            raise Discourse::NotFound
          end
        end

        render_metadata(artifact.name)
      end

      def show
        artifact = AiArtifact.find(params[:id])

        raise Discourse::NotFound if !artifact.available_to?(guardian)

        name = artifact.name
        artifact_version = nil

        if params[:version].present?
          artifact_version = artifact.versions.find_by(version_number: params[:version])
          raise Discourse::NotFound if !artifact_version
        end

        untrusted_html = build_untrusted_html(artifact_version || artifact, name)
        trusted_html = build_trusted_html(artifact, artifact_version, name, untrusted_html)

        set_native_security_headers
        render html: trusted_html.html_safe, layout: false, content_type: "text/html"
      end

      private

      def render_metadata(name)
        response.headers["Cache-Control"] = "no-store"
        response.headers["X-Robots-Tag"] = "noindex"
        render json: { name: name }
      end

      def find_public_share
        share = AiArtifactShare.find_by(share_key: params[:share_key])
        raise Discourse::NotFound if !share&.publicly_visible?

        share
      end

      def build_untrusted_html(artifact, name, standalone: false)
        js = prepare_javascript(artifact.js)
        sanitized_css = artifact.css.to_s.gsub(%r{</style}i, '<\/style')

        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(name)}</title>
              <style>
                #{sanitized_css}
              </style>
              #{standalone ? build_standalone_javascript : build_iframe_javascript}
            </head>
            <body>
              #{artifact.html}
              #{js}
            </body>
          </html>
        HTML
      end

      def build_trusted_html(artifact, artifact_version, name, untrusted_html, standalone: false)
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(name)}</title>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, user-scalable=yes, viewport-fit=cover, interactive-widget=resizes-content">
              #{"<meta name=\"csrf-token\" content=\"#{form_authenticity_token}\">" unless standalone}
              <style>
                html, body, iframe {
                  margin: 0;
                  padding: 0;
                  width: 100%;
                  height: 100%;
                  border: 0;
                  overflow: hidden;
                }
                iframe {
                  overflow: auto;
                }
              </style>
            </head>
            <body>
              <iframe sandbox="allow-scripts allow-forms" title="#{ERB::Util.html_escape(name)}" height="100%" width="100%" srcdoc="#{ERB::Util.html_escape(untrusted_html)}" frameborder="0"></iframe>
              #{build_parent_javascript(artifact) unless standalone}
            </body>
          </html>
        HTML
      end

      def prepare_javascript(js)
        return "" if js.blank?

        if !js.match?(%r{\A\s*<script.*</script>}mi)
          mod = ""
          mod = " type=\"module\"" if js.match?(/\A\s*import.*/)
          js = "<script#{mod}>\n#{js}\n</script>"
        end
        js
      end

      def user_data
        {
          username: current_user ? current_user.username : nil,
          user_id: current_user ? current_user.id : nil,
          name: current_user ? current_user.name : nil,
        }
      end

      def build_standalone_javascript
        <<~JAVASCRIPT
          <script>
            window.discourseArtifactData = {};
            window.discourseArtifactReady = Promise.resolve(window.discourseArtifactData);
            window.discourseArtifact = {
              get: function() { return Promise.reject(new Error('Key-value storage is unavailable in public shares')); },
              set: function() { return Promise.reject(new Error('Key-value storage is unavailable in public shares')); },
              delete: function() { return Promise.reject(new Error('Key-value storage is unavailable in public shares')); },
              index: function() { return Promise.reject(new Error('Key-value storage is unavailable in public shares')); }
            };
          </script>
        JAVASCRIPT
      end

      def build_iframe_javascript
        <<~JAVASCRIPT
          <script>
            window._discourse_user_data = #{user_data.to_json};

            window.discourseArtifactReady = new Promise(resolve => {
              window._resolveArtifactData = resolve;
            });

            // Key-value store API
            window.discourseArtifact = {
              get: function(key) {
                return window._postMessageRequest('get', { key: key });
              },
              set: function(key, value, options = {}) {
                return window._postMessageRequest('set', {
                  key: key,
                  value: value,
                  public: options.public || false
                });
              },
              delete: function(key) {
                return window._postMessageRequest('delete', { key: key });
              },
              index: function(filter = {}) {
                return window._postMessageRequest('index', filter);
              }
            };

            window._postMessageRequest = function(action, data) {
              return new Promise((resolve, reject) => {
                const requestId = Math.random().toString(36).substr(2, 9);
                const messageHandler = function(event) {
                  if (event.data && event.data.requestId === requestId) {
                    window.removeEventListener('message', messageHandler);
                    if (event.data.error) {
                      reject(new Error(event.data.error));
                    } else {
                      resolve(event.data.result);
                    }
                  }
                };
                window.addEventListener('message', messageHandler);
                window.parent.postMessage({
                  type: 'discourse-artifact-kv',
                  action: action,
                  data: data,
                  requestId: requestId
                }, '*');
              });
            };

            window.addEventListener('message', function(event) {
              if (event.data && event.data.type === 'discourse-artifact-data') {
                window.discourseArtifactData = event.data.dataset || {};
                Object.assign(window.discourseArtifactData, window._discourse_user_data);
                window._resolveArtifactData(window.discourseArtifactData);
              }
            });
          </script>
        JAVASCRIPT
      end

      def build_parent_javascript(artifact)
        storage_url =
          if artifact.is_a?(AiArtifactShare)
            "/discourse-ai/ai-bot/artifact-share-key-values/#{artifact.share_key}.json"
          else
            "/discourse-ai/ai-bot/artifact-key-values/#{artifact.id}.json"
          end

        <<~JAVASCRIPT
          <script>
            const iframe = document.querySelector('iframe');

            iframe.addEventListener('load', function() {
              try {
                const iframeWindow = this.contentWindow;
                const message = { type: 'discourse-artifact-data', dataset: {} };

                if (window.frameElement && window.frameElement.dataset) {
                  Object.assign(message.dataset, window.frameElement.dataset);
                }
                iframeWindow.postMessage(message, '*');
              } catch (e) {
                console.error('Error passing data to artifact:', e);
              }
            });

            // Handle key-value store requests from iframe
            window.addEventListener('message', async function(event) {
              if (event.data && event.data.type === 'discourse-artifact-kv') {
                if (event.source !== iframe.contentWindow) return;
                const { action, data, requestId } = event.data;
                const baseUrl = #{storage_url.to_json};

                try {
                  const result = await handleKeyValueRequest(action, data, baseUrl);
                  event.source.postMessage({
                    requestId: requestId,
                    result: result
                  }, '*');
                } catch (error) {
                  event.source.postMessage({
                    requestId: requestId,
                    error: error.message
                  }, '*');
                }
              }
            });

            async function handleKeyValueRequest(action, data, baseUrl) {
              const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content || '';

              switch (action) {
                case 'get':
                  return await handleGetRequest(baseUrl, data, csrfToken);
                case 'set':
                  return await handleSetRequest(baseUrl, data, csrfToken);
                case 'index':
                  return await handleIndexRequest(baseUrl, data, csrfToken);
                case 'delete':
                  return await handleDeleteRequest(baseUrl, data, csrfToken);
                default:
                  throw new Error('Unknown action: ' + action);
              }
            }

            async function handleGetRequest(baseUrl, data, csrfToken) {
              const response = await fetch(baseUrl + '?key=' + encodeURIComponent(data.key), {
                method: 'GET',
                headers: {
                  'X-CSRF-Token': csrfToken,
                  'Content-Type': 'application/json'
                },
                credentials: 'same-origin'
              });

              if (!response.ok) throw new Error('Failed to get key-value');

              const result = await response.json();
              const keyValue = result.key_values.find(kv => kv.key === data.key);
              return keyValue ? keyValue.value : null;
            }

            async function handleSetRequest(baseUrl, data, csrfToken) {
              const response = await fetch(baseUrl, {
                method: 'POST',
                headers: {
                  'X-CSRF-Token': csrfToken,
                  'Content-Type': 'application/json'
                },
                credentials: 'same-origin',
                body: JSON.stringify({
                  key: data.key,
                  value: data.value,
                  public: data.public
                })
              });

              if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Failed to set key-value');
              }

              return await response.json();
            }

            async function handleDeleteRequest(baseUrl, data, csrfToken) {
              const response = await fetch(baseUrl, {
                method: 'DELETE',
                body: JSON.stringify({ key: data.key }),
                headers: {
                  'X-CSRF-Token': csrfToken,
                  'Content-Type': 'application/json'
                },
                credentials: 'same-origin'
              });

              if (!response.ok) {
                if (response.status === 404) {
                  throw new Error('Key not found');
                }
                const errorData = await response.json();
                throw new Error(errorData.errors ? errorData.errors.join(', ') : 'Failed to delete key-value');
              }

              return true;
            }

            async function handleIndexRequest(baseUrl, data, csrfToken) {
              const params = new URLSearchParams();
              if (data.key) params.append('key', data.key);
              if (data.all_users) params.append('all_users', data.all_users);
              if (data.keys_only) params.append('keys_only', data.keys_only);
              if (data.page) params.append('page', data.page);
              if (data.per_page) params.append('per_page', data.per_page);

              const response = await fetch(baseUrl + '?' + params.toString(), {
                method: 'GET',
                headers: {
                  'X-CSRF-Token': csrfToken,
                  'Content-Type': 'application/json'
                },
                credentials: 'same-origin'
              });

              if (!response.ok) throw new Error('Failed to get key-values');

              const result = await response.json();
              const userMap = {};
              result.users.forEach(user => {
                userMap[user.id] = user;
              });
              result.key_values.forEach(kv => {
                if (kv.user_id && userMap[kv.user_id]) {
                  kv.user = userMap[kv.user_id];
                }
              });

              return result;
            }
          </script>
        JAVASCRIPT
      end

      def set_native_security_headers
        set_security_headers
        response.headers["X-Frame-Options"] = "SAMEORIGIN"
        response.headers["Content-Security-Policy"] += " frame-ancestors 'self';"
      end

      def set_security_headers
        response.headers.delete("X-Frame-Options")
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers[
          "Content-Security-Policy"
        ] = "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' #{AiArtifact::ALLOWED_CDN_SOURCES.join(" ")};"
        response.headers["X-Robots-Tag"] = "noindex"
      end

      def require_site_settings!
        if !SiteSetting.discourse_ai_enabled ||
             !SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict])
          raise Discourse::NotFound
        end
      end
    end
  end
end
