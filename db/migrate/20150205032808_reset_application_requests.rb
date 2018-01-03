class ResetApplicationRequests < ActiveRecord::Migration[4.2]

  def up
    # enum changed we need to clear the data
    execute 'TRUNCATE TABLE application_requests'
  end

  def down
  end
end
