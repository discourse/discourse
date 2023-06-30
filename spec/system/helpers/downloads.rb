# frozen_string_literal: true

class Downloads
  FOLDER = "tmp/downloads"

  def self.clear
    FileUtils.rm_rf(FOLDER)
  end
end
