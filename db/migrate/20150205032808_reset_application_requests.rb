class ResetApplicationRequests < ActiveRecord::Migration

  def up
    # enum changed we need to clear the data
    execute 'TRUNCATE TABLE application_requests'
  end

  def down
  end
end
