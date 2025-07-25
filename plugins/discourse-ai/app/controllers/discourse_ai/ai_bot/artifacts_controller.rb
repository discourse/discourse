# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactsController < ApplicationController
      requires_plugin DiscourseAi::PLUGIN_NAME
      before_action :require_site_settings!

      skip_before_action :preload_json, :check_xhr, only: %i[show]

      def show
        artifact = AiArtifact.find(params[:id])

        post = Post.find_by(id: artifact.post_id)
        if artifact.public?
          # no guardian needed
        else
          raise Discourse::NotFound if !post&.topic&.private_message?
          raise Discourse::NotFound if !guardian.can_see?(post)
        end

        name = artifact.name
        artifact_version = nil

        if params[:version].present?
          artifact_version = artifact.versions.find_by(version_number: params[:version])
          raise Discourse::NotFound if !artifact_version
        end

        untrusted_html = build_untrusted_html(artifact_version || artifact, name)
        trusted_html = build_trusted_html(artifact, artifact_version, name, untrusted_html)

        set_security_headers
        render html: trusted_html.html_safe, layout: false, content_type: "text/html"
      end

      private

      def build_untrusted_html(artifact, name)
        js = prepare_javascript(artifact.js)

        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(name)}</title>
              <style>
                #{artifact.css}
              </style>
              #{build_iframe_javascript}
            </head>
            <body>
              #{artifact.html}
              #{js}
            </body>
          </html>
        HTML
      end

      def build_trusted_html(artifact, artifact_version, name, untrusted_html)
        <<~HTML
          <!DOCTYPE html>
          <html>
            <head>
              <meta charset="UTF-8">
              <title>#{ERB::Util.html_escape(name)}</title>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, minimum-scale=1.0, user-scalable=yes, viewport-fit=cover, interactive-widget=resizes-content">
              <meta name="csrf-token" content="#{form_authenticity_token}">
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
              <iframe sandbox="allow-scripts allow-forms" height="100%" width="100%" srcdoc="#{ERB::Util.html_escape(untrusted_html)}" frameborder="0"></iframe>
              #{build_parent_javascript(artifact)}
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
        <<~JAVASCRIPT
          <script>
            document.querySelector('iframe').addEventListener('load', function() {
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
                const { action, data, requestId } = event.data;
                const artifactId = #{artifact.id};

                try {
                  const result = await handleKeyValueRequest(action, data, artifactId);
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

            async function handleKeyValueRequest(action, data, artifactId) {
              const baseUrl = '/discourse-ai/ai-bot/artifact-key-values/' + artifactId + ".json";
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

      def set_security_headers
        response.headers.delete("X-Frame-Options")
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
