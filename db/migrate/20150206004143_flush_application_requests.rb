# frozen_string_literal: true

class FlushApplicationRequests < ActiveRecord::Migration[4.2]
  def up
    # flush as enum changed
    execute "TRUNCATE TABLE application_requests"
  end
  def down
  end
end
