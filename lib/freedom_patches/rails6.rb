# this is a quick backport of a new method introduced in Rails 6
# to be removed after we upgrade to Rails 6
if ! defined? ActionView::Base.with_view_paths
  class ActionView::Base
    class << self
      alias with_view_paths new
    end
  end
end
