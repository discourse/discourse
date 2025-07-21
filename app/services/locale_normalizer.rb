# frozen_string_literal: true

class LocaleNormalizer
  # Normalizes locale string, matching the list of I18n.locales where possible
  # @param locale [String,Symbol] the locale to normalize
  # @return [String] the normalized locale
  def self.normalize_to_i18n(locale)
    return nil if locale.blank?
    locale = locale.to_s.gsub("-", "_")

    i18n_pairs.each { |downcased, value| return value if locale.downcase == downcased }

    locale
  end

  # Checks if two locales are the same based on exact match and normalized match
  # - is_same?("a_b", "a-b") == true
  # - is_same?("a_b", "a") == true
  # @param locale1 [String,Symbol] the first locale to compare
  # @param locale2 [String,Symbol] the second locale to compare
  def self.is_same?(locale1, locale2)
    locale1 = locale1.to_s
    locale2 = locale2.to_s
    return true if locale1 == locale2
    locale1 = locale1.gsub("-", "_").downcase
    locale2 = locale2.gsub("-", "_").downcase
    locale1.split("_").first == locale2.split("_").first
  end

  private

  def self.i18n_pairs
    # they should look like this for the input to match against:
    # {
    #   "lowercased" => "actual",
    #   "en" => "en",
    #   "zh_cn" => "zh_CN",
    #   "zh" => "zh_CN",
    # }
    @locale_map ||=
      I18n
        .available_locales
        .reduce({}) do |output, sym|
          locale = sym.to_s
          output[locale.downcase] = locale
          if locale.include?("_")
            short = locale.split("_").first
            output[short] = locale if output[short].blank?
          end
          output
        end
  end
end
