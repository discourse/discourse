# frozen_string_literal: true

module RouteFormat
  def self.username
    /[%\w.\-]+?/
  end

  def self.backup
    /[a-zA-Z0-9._-]+\.(sql\.gz|tar\.gz|tgz)/i
  end
end
