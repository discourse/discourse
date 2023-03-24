# frozen_string_literal: true

module GitUrl
  class << self
    SSH_REGEXP = /\A(\w+@\w+(\.\w+)*):(.*)\z/

    def normalize(url)
      if m = SSH_REGEXP.match(url)
        url = "ssh://#{m[1]}/#{m[3]}"
      end

      if url.start_with?("https://github.com/") && !url.end_with?(".git")
        url = url.gsub(%r{/\z}, "")
        url += ".git"
      end

      url
    end
  end
end
