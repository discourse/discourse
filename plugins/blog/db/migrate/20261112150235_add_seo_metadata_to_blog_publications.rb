# frozen_string_literal: true
class AddSeoMetadataToBlogPublications < ActiveRecord::Migration[8.1]
  def change
    add_column :blog_publications, :meta_description, :string, null: false, default: ""
    add_column :blog_publications, :canonical_url, :string, null: false, default: ""
  end
end
