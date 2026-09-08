# frozen_string_literal: true

module RouteFormat
  class << self
    def username
      /[%\w.\-]+?/
    end

    def backup
      /[a-zA-Z0-9._-]+\.(sql\.gz|tar\.gz|tgz)/i
    end
  end
end
