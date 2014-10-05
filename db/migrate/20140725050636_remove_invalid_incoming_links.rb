class RemoveInvalidIncomingLinks < ActiveRecord::Migration
  def change
    execute "DELETE FROM incoming_links WHERE url ILIKE '%avatar%.png'"
  end
end
