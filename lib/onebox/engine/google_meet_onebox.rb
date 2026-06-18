# frozen_string_literal: true

module Onebox
  module Engine
    class GoogleMeetOnebox
      include Engine
      include LayoutSupport

      MEETING_CODE_PATH = %r{\A/(?<code>[a-z]{3}-[a-z]{4}-[a-z]{3})/?\z}i
      LOOKUP_PATH = %r{\A/lookup/[a-z0-9_-]{3,64}/?\z}i

      matches_domain("meet.google.com")
      always_https

      def self.matches_path(path)
        path.match?(MEETING_CODE_PATH) || path.match?(LOOKUP_PATH)
      end

      def inline_data
        { title: I18n.t("onebox.google_meet.title") }
      end

      private

      def data
        @data ||=
          begin
            meeting_code = parsed_meeting_code

            {
              link: link,
              domain: "Google Meet",
              title: I18n.t("onebox.google_meet.title"),
              description: meeting_code.blank? ? I18n.t("onebox.google_meet.description") : nil,
              meeting_code: meeting_code,
              meeting_code_label: I18n.t("onebox.google_meet.meeting_code"),
              join_label: I18n.t("onebox.google_meet.join"),
            }
          end
      end

      def parsed_meeting_code
        match = uri.path.match(MEETING_CODE_PATH)
        match&.[](:code)&.downcase
      end
    end
  end
end
