# perf fixes, review for each rails upgrade.

# we call this a lot
class ActiveRecord::Base
  def present?
    true
  end
  def blank?
    false
  end
end
