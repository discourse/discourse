# frozen_string_literal: true

class Downloads
  FOLDER = Rails.root.join("tmp/downloads#{ENV["TEST_ENV_NUMBER"]}")

  class << self
    def clear
      FileUtils.rm_rf(FOLDER)
    end
  end
end
