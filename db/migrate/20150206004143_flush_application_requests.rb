class FlushApplicationRequests < ActiveRecord::Migration
  def up
    # flush as enum changed
    execute "TRUNCATE TABLE application_requests"
  end
  def down
  end
end
