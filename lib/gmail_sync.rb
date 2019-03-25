require 'google/apis/gmail_v1'
require 'googleauth'

class GmailSync

  APPLICATION_NAME = "Discourse Sync Service"
  GMAIL_REDIRECT_URI = "urn:ietf:wg:oauth:2.0:oob"

  GMAIL_CLIENT_ID_FIELD = "gmail_client_id"
  GMAIL_CLIENT_SECRET_FIELD = "gmail_client_secret"
  GMAIL_TOKEN_FIELD = "gmail_token"

  GMAIL_HISTORY_ID_FIELD = "gmail_history_id"
  GMAIL_TOPIC_NAME_FIELD = "gmail_topic_name"

  def self.credentials_for(group)
    return nil if !group.custom_fields[GMAIL_CLIENT_ID_FIELD] ||
                  !group.custom_fields[GMAIL_CLIENT_SECRET_FIELD] ||
                  !group.custom_fields[GMAIL_TOKEN_FIELD] ||
                  !group.custom_fields[GMAIL_TOPIC_NAME_FIELD]

    credentials = Google::Auth::UserRefreshCredentials.new(
      client_id: group.custom_fields[GMAIL_CLIENT_ID_FIELD],
      client_secret: group.custom_fields[GMAIL_CLIENT_SECRET_FIELD],
      scope: Google::Apis::GmailV1::AUTH_SCOPE,
      redirect_uri: GMAIL_REDIRECT_URI,
      refresh_token: group.custom_fields[GMAIL_TOKEN_FIELD]
    )
    credentials.fetch_access_token!
    credentials
  end

  def self.service_for(group)
    credentials = credentials_for(group)
    return if !credentials

    service = Google::Apis::GmailV1::GmailService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = credentials
    service
  end

end
