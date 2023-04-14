# frozen_string_literal: true

module Onebox
  module Engine
    class StackExchangeOnebox
      include Engine
      include LayoutSupport
      include JSON

      def self.domains
        %w[
          stackexchange.com
          stackoverflow.com
          superuser.com
          serverfault.com
          askubuntu.com
          stackapps.com
          mathoverflow.net
        ].map { |domain| Regexp.escape(domain) }
      end

      matches_regexp(
        %r{^https?://(?:(?:(?<subsubdomain>\w*)\.)?(?<subdomain>\w*)\.)?(?<domain>#{domains.join("|")})/((?:questions|q)/(?<question_id>\d*)(/.*/(?<answer_id1>\d*))?|(a/(?<answer_id2>\d*)))},
      )

      def always_https?
        uri.host.split(".").length <= 3
      end

      private

      def match
        @match ||= @url.match(@@matcher)
      end

      def url
        domain = uri.host
        question_id = match[:question_id]
        answer_id = match[:answer_id2] || match[:answer_id1]

        if answer_id
          "https://api.stackexchange.com/2.2/answers/#{answer_id}?site=#{domain}&filter=!.FjueITQdx6-Rq3Ue9PWG.QZ2WNdW"
        else
          "https://api.stackexchange.com/2.2/questions/#{question_id}?site=#{domain}&filter=!5-duuxrJa-iw9oVvOA(JNimB5VIisYwZgwcfNI"
        end
      end

      def data
        return @data if defined?(@data)

        result = raw["items"][0]
        if result
          result["creation_date"] = Time.at(result["creation_date"].to_i).strftime(
            "%I:%M%p - %d %b %y %Z",
          )

          result["tags"] = result["tags"].take(4).join(", ")
          result["is_answer"] = result.key?("answer_id")
          result["is_question"] = result.key?("question_id")
        end

        @data = result
      end
    end
  end
end
