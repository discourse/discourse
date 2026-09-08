# frozen_string_literal: true

class MailingListModeSiteSetting < EnumSiteSetting
  class << self
    def valid_value?(val)
      val.to_i.to_s == val.to_s && values.any? { |v| v[:value] == val.to_i }
    end

    def values
      @values ||= [
        { name: "user.mailing_list_mode.individual", value: 1 },
        { name: "user.mailing_list_mode.individual_no_echo", value: 2 },
      ]
    end

    def translate_names?
      true
    end
  end
end
