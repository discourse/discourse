# frozen_string_literal: true

class Auth::OmniAuthStrategies
  class DiscourseGoogleOauth2 < OmniAuth::Strategies::GoogleOauth2
    GROUPS_SCOPE ||= "admin.directory.group.readonly"
    GROUPS_DOMAIN ||= "admin.googleapis.com"
    GROUPS_PATH ||= "/admin/directory/v1/groups"

    def extra
      hash = {}
      hash[:raw_info] = raw_info
      hash[:raw_groups] = raw_groups if options[:request_groups]
      hash
    end

    def raw_groups
      @raw_groups ||= begin
        groups = []
        page_token = nil
        groups_url = "https://#{GROUPS_DOMAIN}#{GROUPS_PATH}"

        loop do
          params = {
            userKey: uid
          }
          params[:pageToken] = page_token if page_token

          response = access_token.get(groups_url, params: params, raise_errors: false)

          if response.status == 200
            response = response.parsed
            groups.push(*response['groups'])
            page_token = response['nextPageToken']
            break if page_token.nil?
          else
            Rails.logger.error("[Discourse Google OAuth2] failed to retrieve groups for #{uid} - status #{response.status}")
            break
          end
        end

        groups
      end
    end
  end
end
