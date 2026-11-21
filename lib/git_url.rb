# frozen_string_literal: true

module GitUrl
  class << self
    SSH_REGEXP = /\A(\w+@\w+(\.\w+)*):(.*)\z/

    def normalize(url)
      if m = SSH_REGEXP.match(url)
        url = "ssh://#{m[1]}/#{m[3]}"
      end

      # Any https git remote (not just GitHub) accepts both "/repo" and
      # "/repo.git" as a clone URL, so canonicalize all of them the same
      # way -- otherwise two equally-valid references to the same non-GitHub
      # repo (e.g. from an about.json child_components list vs. what an
      # admin actually typed) fail RemoteTheme's exact-string URL matching.
      if url.start_with?("https://") && !url.end_with?(".git")
        url = url.gsub(%r{/\z}, "")
        url += ".git"
      end

      url
    end
  end
end
