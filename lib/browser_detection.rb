# frozen_string_literal: true

module BrowserDetection
  EDGE_REGEXP = /Edg/i
  OPERA_REGEXP = /Opera|OPR/i
  SAMSUNG_BROWSER_REGEXP = %r{SamsungBrowser/}i
  UC_BROWSER_REGEXP = %r{(?:UCBrowser|UC Browser)[/ ]}i
  QQ_BROWSER_REGEXP = %r{(?:MQQBrowser|QQBrowser)/}i
  BAIDU_BROWSER_REGEXP = %r{(?:BIDUBrowser|BaiduBrowser)/}i
  KAIOS_BROWSER_REGEXP = %r{KaiOS/}i
  IE_REGEXP = /MSIE|Trident|IEMobile/i
  FIREFOX_REGEXP = /Firefox|FxiOS/i
  CHROME_REGEXP = /Chrome|CriOS/i
  ANDROID_BROWSER_REGEXP = %r{Android.+Version/[\d.]+.+Safari/}i
  SAFARI_REGEXP = /Safari/i
  DISCOURSE_REGEXP = /Discourse/i

  ANDROID_REGEXP = /Android/i
  CROS_REGEXP = /CrOS/i
  IPAD_REGEXP = /iPad/i
  IPHONE_REGEXP = /iPhone/i
  IPOD_REGEXP = /iPod/i
  MOBILE_REGEXP = /Mobile/i
  MAC_REGEXP = /Macintosh/i
  LINUX_REGEXP = /Linux/i
  WINDOWS_REGEXP = /Windows/i
  IOS_REGEXP = /iPhone|iPad|iPod|Darwin/i

  def self.browser(user_agent)
    return :unknown if !user_agent

    if EDGE_REGEXP.match?(user_agent)
      :edge
    elsif OPERA_REGEXP.match?(user_agent)
      :opera
    elsif SAMSUNG_BROWSER_REGEXP.match?(user_agent)
      :samsung_browser
    elsif UC_BROWSER_REGEXP.match?(user_agent)
      :uc_browser
    elsif QQ_BROWSER_REGEXP.match?(user_agent)
      :qq_browser
    elsif BAIDU_BROWSER_REGEXP.match?(user_agent)
      :baidu_browser
    elsif KAIOS_BROWSER_REGEXP.match?(user_agent)
      :kaios_browser
    elsif IE_REGEXP.match?(user_agent)
      :ie
    elsif FIREFOX_REGEXP.match?(user_agent)
      :firefox
    elsif CHROME_REGEXP.match?(user_agent)
      :chrome
    elsif ANDROID_BROWSER_REGEXP.match?(user_agent)
      :android_browser
    elsif SAFARI_REGEXP.match?(user_agent)
      :safari
    elsif DISCOURSE_REGEXP.match?(user_agent)
      :discoursehub
    else
      :unknown
    end
  end

  def self.device(user_agent)
    return :unknown if !user_agent

    if ANDROID_REGEXP.match?(user_agent)
      :android
    elsif CROS_REGEXP.match?(user_agent)
      :chromebook
    elsif IPAD_REGEXP.match?(user_agent)
      :ipad
    elsif IPHONE_REGEXP.match?(user_agent)
      :iphone
    elsif IPOD_REGEXP.match?(user_agent)
      :ipod
    elsif MOBILE_REGEXP.match?(user_agent)
      :mobile
    elsif MAC_REGEXP.match?(user_agent)
      :mac
    elsif LINUX_REGEXP.match?(user_agent)
      :linux
    elsif WINDOWS_REGEXP.match?(user_agent)
      :windows
    else
      :unknown
    end
  end

  def self.os(user_agent)
    return :unknown if !user_agent

    if ANDROID_REGEXP.match?(user_agent)
      :android
    elsif CROS_REGEXP.match?(user_agent)
      :chromeos
    elsif IOS_REGEXP.match?(user_agent)
      :ios
    elsif MAC_REGEXP.match?(user_agent)
      :macos
    elsif LINUX_REGEXP.match?(user_agent)
      :linux
    elsif WINDOWS_REGEXP.match?(user_agent)
      :windows
    else
      :unknown
    end
  end
end
