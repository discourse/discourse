# frozen_string_literal: true
class AddAsnOrganizationToBrowserPageviewEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :browser_pageview_events, :asn_organization, :string
  end
end
