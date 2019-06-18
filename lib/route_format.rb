# frozen_string_literal: true

module RouteFormat

  def self.username
    /[%\w.\-]+?/
  end

  def self.backup
    /.+\.(sql\.gz|tar\.gz|tgz)/i
  end

end
