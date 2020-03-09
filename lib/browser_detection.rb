# frozen_string_literal: true

module BrowserDetection

  def self.browser(user_agent)
    case user_agent
    when /Edg/i
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
    when /Discourse/i
      :discoursehub
    else
      :unknown
    end
  end

  def self.device(user_agent)
    case user_agent
    when /Android/i
      :android
    when /CrOS/i
      :chromebook
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
    when /CrOS/i
      :chromeos
    when /iPhone|iPad|iPod|Darwin/i
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
