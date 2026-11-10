# frozen_string_literal: true

module Email
  class AuthenticationResults
    # ordered by severity
    VERDICTS = %i[gray pass fail].freeze

    # based on https://tools.ietf.org/html/rfc8601#section-2.2
    CFWS = /\s*(?:\([^()]*\))?\s*/
    VALUE = /(?:"([^"]*)")|(?:([^\s";]*))/
    VERSION = /\d+#{CFWS}?/
    KEYWORD = /([a-zA-Z0-9-]*[a-zA-Z0-9])/
    NO_RESULT = /#{CFWS}?;#{CFWS}?none#{CFWS}?\z/i
    PAYLOAD = /\A#{CFWS}?#{VALUE}(?:#{CFWS}#{VERSION})?(?:#{NO_RESULT}|([\S\s]*))/
    METHODSPEC =
      %r{#{CFWS}?#{KEYWORD}\s*(?:#{CFWS}?/#{CFWS}?#{VERSION})?#{CFWS}?=#{CFWS}?#{KEYWORD}}
    REASONSPEC = /reason#{CFWS}?=#{CFWS}?#{VALUE}/
    RESINFO = /#{CFWS}?;#{METHODSPEC}(?:#{CFWS}#{REASONSPEC})?(?:#{CFWS}([^;]*))?/
    PROPSPEC = /#{KEYWORD}#{CFWS}?\.#{CFWS}?#{VALUE}#{CFWS}?=#{CFWS}?#{VALUE}#{CFWS}?/
    private_constant :CFWS,
                     :VALUE,
                     :VERSION,
                     :KEYWORD,
                     :NO_RESULT,
                     :PAYLOAD,
                     :METHODSPEC,
                     :REASONSPEC,
                     :RESINFO,
                     :PROPSPEC

    def initialize(headers)
      @authserv_id = SiteSetting.email_in_authserv_id
      @headers = headers
    end

    def results
      @results ||=
        Array(@headers)
          .map { |header| parse_header(header.to_s) }
          .filter { |result| @authserv_id.blank? || @authserv_id == result[:authserv_id] }
    end

    def verdict
      @verdict ||= calc_verdict
    end

    def action
      verdict == :fail ? :enqueue : :accept
    end

    private

    def calc_verdict
      # without a trusted authserv-id, any MTA along the way could have forged the header
      return :gray if @authserv_id.blank?

      severity =
        results
          .flat_map { |result| result[:resinfo] }
          .filter_map do |resinfo|
            VERDICTS.index(resinfo[:result].downcase.to_sym) if resinfo[:method].casecmp?("dmarc")
          end
          .max

      VERDICTS[severity || 0]
    end

    def parse_header(header)
      authserv_id_quoted, authserv_id, resinfo = PAYLOAD.match(header).captures

      {
        authserv_id: authserv_id_quoted || authserv_id,
        resinfo:
          resinfo
            .to_s
            .scan(RESINFO)
            .map do |method, result, reason_quoted, reason, props|
              {
                method:,
                result:,
                reason: reason_quoted || reason,
                props:
                  props
                    .scan(PROPSPEC)
                    .map do |ptype, property_quoted, property, pvalue_quoted, pvalue|
                      {
                        ptype:,
                        property: property_quoted || property,
                        pvalue: pvalue_quoted || pvalue,
                      }
                    end,
              }
            end,
      }
    end
  end
end
