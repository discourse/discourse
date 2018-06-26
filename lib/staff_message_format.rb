# This is used for formatting Suspension/Silencing messages.
# It can be extended by plugins to provide custom message formats.
class StaffMessageFormat
  def initialize(type, reason, message = nil)
    @type = type
    @reason = reason
    @message = message

    after_initialize
  end

  # Plugins can overwrite this to munge values before formatting
  def after_initialize
  end

  # Overwrite this to change formatting
  def format
    result = ""
    result << @reason if @reason.present?
    result << "\n\n#{@message}" if @message.present?
    result
  end
end
