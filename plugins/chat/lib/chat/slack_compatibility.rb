# frozen_string_literal: true

##
# Processes slack-formatted text messages, as Mattermost does with
# Slack incoming webhook interoperability, for example links in the
# format <LINK> and <LINK|TEXT>, <!here> and <!all> mentions.
#
# See https://api.slack.com/reference/surfaces/formatting for all of
# the different formatting slack supports with mrkdwn which is mostly
# identical to Markdown.
#
# Mattermost docs for translating the slack format:
#
# https://docs.mattermost.com/developer/webhooks-incoming.html?highlight=translate%20slack%20data%20format%20mattermost#translate-slack-s-data-format-to-mattermost
#
# We may want to process attachments and blocks from slack in future, and
# convert user IDs into user mentions.
module Chat
  class SlackCompatibility
    MRKDWN_LINK_REGEX = Regexp.new(/(<[^\n<\|>]+>|<[^\n<\>]+>)/).freeze

    class << self
      def process_text(text)
        text = text.gsub("<!here>", "@here")
        text = text.gsub("<!all>", "@all")

        text.gsub(MRKDWN_LINK_REGEX) do |match|
          link, title = match[1...-1].split("|")[0..1]

          if title
            "[#{title}](#{link})"
          else
            link
          end
        end
      end

      def legacy_attachment_text(attachments)
        CGI.unescape(attachments[0][:fallback])
      end

      # TODO: This is quite hacky and is only here to support a single
      # attachment for our OpsGenie integration. In future we would
      # want to iterate through this attachments array and extract
      # things properly.
      #
      # See https://api.slack.com/reference/messaging/attachments for
      # more details on what fields are here.
      def process_legacy_attachments(attachments)
        process_text(legacy_attachment_text(attachments))
      end
    end
  end
end
