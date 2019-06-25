# frozen_string_literal: true

module RouteFormat
  USERNAME_REGEXP = '[%\w.\-]+?'

  def self.username
    /#{USERNAME_REGEXP}/
  end

  def self.backup
    /.+\.(sql\.gz|tar\.gz|tgz)/i
  end

end
