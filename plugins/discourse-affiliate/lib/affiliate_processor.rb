# frozen_string_literal: true

class AffiliateProcessor
  def self.create_amazon_rule(domain)
    lambda do |url, uri|
      code = SiteSetting.get("affiliate_amazon_#{domain.gsub(".", "_")}")
      if code.present?
        original_query_array = URI.decode_www_form(String(uri.query)).to_h
        query_array = [["tag", code]]
        query_array << ["k", original_query_array["k"]] if original_query_array["k"].present?
        if original_query_array["ref"].present? && original_query_array["k"].present?
          query_array << ["ref", original_query_array["ref"]]
        end
        if original_query_array["node"].present?
          query_array << ["node", original_query_array["node"]]
        end
        uri.query = URI.encode_www_form(query_array)
        uri.to_s
      else
        url
      end
    end
  end

  def self.rules
    return @rules if @rules
    postfixes = %w[com com.au com.br com.mx ca cn co.jp co.uk de es fr in it nl to co eu]

    rules = {}

    postfixes.map do |postfix|
      rule = create_amazon_rule(postfix)

      rules["amzn.com"] = rule if postfix == "com"
      rules["amzn.to"] = create_amazon_rule("com") if postfix == "to"
      rules["amzn.eu"] = rule if postfix == "eu"
      rules["a.co"] = create_amazon_rule("com") if postfix == "co"
      rules["www.amazon.#{postfix}"] = rule
      rules["smile.amazon.#{postfix}"] = rule
      rules["amazon.#{postfix}"] = rule
    end

    rule =
      lambda do |url, uri|
        code = SiteSetting.affiliate_ldlc_com
        if code.present?
          uri.fragment = code
          uri.to_s
        else
          url
        end
      end

    rules["www.ldlc.com"] = rule
    rules["ldlc.com"] = rule

    @rules = rules
  end

  def self.apply(url)
    uri = URI.parse(url)

    if uri.scheme == "http" || uri.scheme == "https"
      rule = rules[uri.host]
      return rule.call(url, uri) if rule
    end

    url
  rescue StandardError
    url
  end
end
