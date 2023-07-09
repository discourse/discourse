# frozen_string_literal: true

class Downloads
  FOLDER = "tmp/downloads"
  TIMEOUT = 10

  def self.wait_for_download
    Timeout.timeout(TIMEOUT) do
      until downloaded?
        sleep 0.1
        puts "1234 DOWNLOADS 1 #{Dir[Pathname.new(FOLDER).join("*")]}"
        puts "1234 DOWNLOADS 2 #{Dir[Rails.root.join(FOLDER).join("*")]}"
        puts "1234 Rails.root #{Rails.root}"
        puts "1234 Downloads folder #{Rails.root.join(FOLDER)}"
      end
    end
  end

  def self.clear
    FileUtils.rm_rf(FOLDER)
  end

  private

  # fixme andrei use it instead of reading the name of the file from the page
  def self.downloads
    Dir[Pathname.new(FOLDER).join("*")]
  end

  def self.downloaded?
    !downloading? && downloads.any?
  end

  def self.downloading?
    downloads.grep(/\.crdownload$/).any?
  end

  private_class_method :downloads, :downloaded?, :downloading?
end
