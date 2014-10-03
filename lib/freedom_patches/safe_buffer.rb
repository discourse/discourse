# For some reason safe buffer is getting invalid encoding in some cases
# we work around the issue and log the problems
#
# The alternative is a broken website when this happens

class ActiveSupport::SafeBuffer
  def concat(value, raise_encoding_err=false)
    if !html_safe? || value.html_safe?
      super(value)
    else
      super(ERB::Util.h(value))
    end
  rescue Encoding::CompatibilityError
    if raise_encoding_err
      raise
    else

      unless encoding == Encoding::UTF_8
        self.force_encoding("UTF-8")
        unless valid_encoding?
          encode!("utf-16","utf-8",:invalid => :replace)
          encode!("utf-8","utf-16")
        end
        Rails.logger.warn("Encountered a non UTF-8 string in SafeBuffer - #{self}")
      end

      unless value.encoding == Encoding::UTF_8
        value = value.dup.force_encoding("UTF-8").scrub
        Rails.logger.warn("Attempted to concat a non UTF-8 string in SafeBuffer - #{value}")
      end

      concat(value,_raise=true)
    end
  end

  alias << concat
end
