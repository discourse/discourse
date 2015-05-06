if Rails.version < "4.2.0"
  class Mail::Message
    alias_method :deliver_now,  :deliver
    alias_method :deliver_now!, :deliver!
  end
end
