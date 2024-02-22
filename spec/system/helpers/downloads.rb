# frozen_string_literal: true

class Downloads
  FOLDER = Rails.root.join("tmp/downloads")
  TIMEOUT = 10

  def self.wait_for_download
    Timeout.timeout(TIMEOUT) { sleep 0.1 until downloaded? }
  end

  def self.clear
    FileUtils.rm_rf(FOLDER)
  end

  private

  def self.downloaded?
    !downloading? && downloads.any?
  end

  def self.downloading?
    downloads.grep(/\.crdownload$/).any?
  end

  def self.downloads
    Dir[FOLDER.join("*")]
  end

  private_class_method :downloaded?, :downloading?, :downloads
end
