unless rails_master?

class Mail::Message
  alias_method :deliver_now,  :deliver
  alias_method :deliver_now!, :deliver!
end

end
