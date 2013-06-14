module UserNotificationsHelper

  def indent(text, by=2)
    spacer = " " * by
    result = ""
    text.each_line do |line|
      result << spacer << line
    end
    result
  end

end
