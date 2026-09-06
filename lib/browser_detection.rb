# frozen_string_literal: true

module BrowserDetection
  def self.browser(user_agent)
    case user_agent
    when /Edg/i
      :edge
    when /Opera/i, /OPR/i
      :opera
    when %r{SamsungBrowser/}i
      :samsung_browser
    when %r{(?:UCBrowser|UC Browser)[/ ]}i
      :uc_browser
    when %r{(?:MQQBrowser|QQBrowser)/}i
      :qq_browser
    when %r{(?:BIDUBrowser|BaiduBrowser)/}i
      :baidu_browser
    when %r{KaiOS/}i
      :kaios_browser
    when /MSIE|Trident|IEMobile/i
      :ie
    when /Firefox/i, /FxiOS/i
      :firefox
    when /Chrome/i, /CriOS/i
      :chrome
    when %r{Android.+Version/[\d.]+.+Safari/}i
      :android_browser
    when /Safari/i
      :safari
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
