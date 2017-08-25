class CreateAnnotatorStore < ActiveRecord::Migration
  def self.up
    create_table :annotator_store_annotations do |t|
      t.string :version   # Schema version
      t.text :text        # Content of annotation
      t.text :quote       # The annotated text
      t.string :uri       # URI of annotated document
      t.timestamps        # Time created_at and updated_at for annotation
    end

    create_table :annotator_store_ranges do |t|
      t.references :annotation, index: true # Associated annotation's id
      t.string :start                       # Relative XPath to start element
      t.string :end                         # Relative XPath to end element
      t.integer :start_offset               # Character offset within start element
      t.integer :end_offset                 # Character offset within end element
      t.timestamps                          # Time created_at and updated_at for range
    end
  end

  def self.down
    drop_table :annotator_store_annotations
    drop_table :annotator_store_ranges
  end
end
