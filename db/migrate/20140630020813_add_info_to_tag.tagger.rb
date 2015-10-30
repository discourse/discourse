# This migration comes from tagger (originally 20140602133824)
# This migration comes from tagger (originally 20140602133824)
class AddInfoToTag < ActiveRecord::Migration
  def change
    add_column :tagger_tags, :info, :text
  end
end
