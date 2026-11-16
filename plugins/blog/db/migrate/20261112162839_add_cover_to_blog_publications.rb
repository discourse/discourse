# frozen_string_literal: true
class AddCoverToBlogPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_publications, :cover_upload_id, :integer
    add_column :blog_publications, :cover_alt, :string, null: false, default: ""
  end
end
