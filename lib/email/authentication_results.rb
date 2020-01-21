# frozen_string_literal: true

module Email
  class AuthenticationResults
    VERDICT = Enum.new(
      :gray,
      :pass,
      :fail,
      start: 0,
    )

    def initialize(headers)
      @authserv_id = SiteSetting.email_in_authserv_id
      @headers = headers
      @verdict = :gray if @authserv_id.blank?
    end

    def results
      @results ||= Array(@headers).map do |header|
        parse_header(header.to_s)
      end.filter do |result|
        @authserv_id.blank? || @authserv_id == result[:authserv_id]
      end
    end

    def action
      @action ||= calc_action
    end

    def verdict
      @verdict ||= calc_verdict
    end

    private

    def calc_action
      if verdict == :fail
        :enqueue
      else
        :accept
      end
    end

    def calc_verdict
      VERDICT[calc_dmarc]
    end

    def calc_dmarc
      verdict = VERDICT[:gray]
      results.each do |result|
        result[:resinfo].each do |resinfo|
          if resinfo[:method] == "dmarc"
            v = VERDICT[resinfo[:result].to_sym].to_i
            verdict = v if v > verdict
          end
        end
      end
      verdict = VERDICT[:gray] if SiteSetting.email_in_authserv_id.blank? && verdict == VERDICT[:pass]
      verdict
    end

    def parse_header(header)
      # based on https://tools.ietf.org/html/rfc8601#section-2.2
      cfws = /\s*(\([^()]*\))?\s*/
      value = /(?:"([^"]*)")|(?:([^\s";]*))/
      authserv_id = value
      authres_version = /\d+#{cfws}?/
      no_result = /#{cfws}?;#{cfws}?none/
      keyword = /([a-zA-Z0-9-]*[a-zA-Z0-9])/
      authres_payload = /\A#{cfws}?#{authserv_id}(?:#{cfws}#{authres_version})?(?:#{no_result}|([\S\s]*))/

      method_version = authres_version
      method = /#{keyword}\s*(?:#{cfws}?\/#{cfws}?#{method_version})?/
      result = keyword
      methodspec = /#{cfws}?#{method}#{cfws}?=#{cfws}?#{result}/
      reasonspec = /reason#{cfws}?=#{cfws}?#{value}/
      resinfo = /#{cfws}?;#{methodspec}(?:#{cfws}#{reasonspec})?(?:#{cfws}([^;]*))?/

      ptype = keyword
      property = value
      pvalue = /#{cfws}?#{value}#{cfws}?/
      propspec = /#{ptype}#{cfws}?\.#{cfws}?#{property}#{cfws}?=#{pvalue}/

      authres_payload_match = authres_payload.match(header)
      parsed_authserv_id = authres_payload_match[2] || authres_payload_match[3]
      resinfo_val = authres_payload_match[-1]

      if resinfo_val
        resinfo_scan = resinfo_val.scan(resinfo)
        parsed_resinfo = resinfo_scan.map do |x|
          {
            method: x[2],
            result: x[8],
            reason: x[12] || x[13],
            props: x[-1].scan(propspec).map do |y|
              {
                ptype: y[0],
                property: y[4],
                pvalue: y[8] || y[9]
              }
            end
          }
        end
      end

      {
        authserv_id: parsed_authserv_id,
        resinfo: parsed_resinfo
      }
    end

  end
end
