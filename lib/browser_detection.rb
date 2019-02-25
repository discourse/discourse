module BrowserDetection

  def self.browser(user_agent)
    case user_agent
    when /Edge/i
      :edge
    when /Opera/i, /OPR/i
      :opera
    when /Firefox/i
      :firefox
    when /Chrome/i, /CriOS/i
      :chrome
    when /Safari/i
      :safari
    when /MSIE/i, /Trident/i
      :ie
    else
      :unknown
    end
  end

  def self.device(user_agent)
    case user_agent
    when /Android/i
      :android
    when /iPad/i
      :ipad
    when /iPhone/i
      :iphone
    when /iPod/i
      :ipod
    when /Mobile/i
      :mobile
    when /Macintosh/i
      :mac
    when /Linux/i
      :linux
    when /Windows/i
      :windows
    else
      :unknown
    end
  end

  def self.os(user_agent)
    case user_agent
    when /Android/i
      :android
    when /iPhone|iPad|iPod/i
      :ios
    when /Macintosh/i
      :macos
    when /Linux/i
      :linux
    when /Windows/i
      :windows
    else
      :unknown
    end
  end

end
