# frozen_string_literal: true

# Discourse ships with a connection reaper
# this patch ensures that the connection reaper never runs in Rails
#
# In Rails 5.2 the connection reaper is "per-pool" this means it can bloat
# threads quite a lot in a multisite
#
# Note, the "correct" way is to set this in the spec, however due to multisite
# getting reaper_interval=0 into all the specs is not going to be trivial
# when we eventually do that we can remove this patch

if !defined? ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper
  raise "Can not find connection Reaper class, this patch will no longer work!"
end

class ActiveRecord::ConnectionAdapters::ConnectionPool::Reaper
  def run
  end
end
