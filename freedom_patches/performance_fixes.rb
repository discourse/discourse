# frozen_string_literal: true

# perf fixes, review for each rails upgrade.

# This speeds up calls to present? and blank? on model instances
# Eg: Topic.new.blank? (which is always false) and so on.
#
# Per: https://gist.github.com/SamSaffron/c8bbc8c7b6bf3b0148760c887df18b55
# Comparison:
#         fast present: 25253295.0 i/s
#       fast present 2: 24623199.7 i/s - same-ish: difference falls within error
#         slow present:   335003.0 i/s - 75.38x  slower
#       slow present 2:   275212.8 i/s - 91.76x  slower
#
#  raised with rails at: https://github.com/rails/rails/issues/35059
class ActiveRecord::Base
  def present?
    true
  end
  def blank?
    false
  end
end
