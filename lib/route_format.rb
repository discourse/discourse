# frozen_string_literal: true

module RouteFormat
  def self.username
    /[%\w.\-]+?/
  end

  def self.backup
    /.+\.(sql\.gz|tar\.gz|tgz)/i
  end

  def self.category_slug_path_with_id
    %r{[^/].+/\d+}
  end
end
