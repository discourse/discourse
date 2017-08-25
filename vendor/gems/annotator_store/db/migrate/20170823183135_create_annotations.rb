class CreateAnnotations < ActiveRecord::Migration


  def change

    create_table :annotator_store_tags do |t|
      t.string :name
      t.text :description
      t.belongs_to :creator, index: true
      t.timestamps
    end

    add_column :annotator_store_annotations, :tag_id, :integer
    add_column :annotator_store_annotations, :post_id, :integer
    add_column :annotator_store_annotations, :creator_id, :integer

    create_table :annotator_store_collections do |t|
      t.string :name
      t.belongs_to :creator, index: true
      t.timestamps
    end

    create_table :annotator_store_collections_tags do |t|
      t.belongs_to :collection, index: true
      t.belongs_to :tag, index: true
      t.timestamps
    end

  end


end
