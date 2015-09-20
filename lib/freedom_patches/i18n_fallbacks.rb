module I18n
  module Backend
    module Fallbacks
      def exists?(locale, key)
        I18n.fallbacks[locale].each do |fallback|
          begin
            return true if super(fallback, key)
          rescue I18n::InvalidLocale
            # we do nothing when the locale is invalid, as this is a fallback anyways.
          end
        end

        false
      end
    end
  end
end
