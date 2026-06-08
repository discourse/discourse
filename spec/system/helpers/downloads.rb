# frozen_string_literal: true

class Downloads
  FOLDER = Rails.root.join("tmp/downloads")

  def self.clear
    FileUtils.rm_rf(FOLDER)
  end
end
