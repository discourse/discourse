# frozen_string_literal: true

class RemoveInvalidIncomingLinks < ActiveRecord::Migration[4.2]
  def change
    execute "DELETE FROM incoming_links WHERE url ILIKE '%avatar%.png'"
  end
end
