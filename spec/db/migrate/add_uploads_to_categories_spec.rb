require 'rails_helper'
require 'migration/column_dropper'
require_relative '../../../db/migrate/20161202034856_add_uploads_to_categories'

RSpec.describe AddUploadsToCategories do
  before do
    %i{logo_url background_url}.each do |column|
      DB.exec("ALTER TABLE categories ADD COLUMN #{column} VARCHAR;")
    end

    %i{uploaded_logo_id uploaded_background_id}.each do |column|
      DB.exec("ALTER TABLE categories DROP COLUMN IF EXISTS #{column}")
    end
  end

  def select_column_from_categories(column, category_id)
    DB.query_single(<<~SQL).first
    SELECT #{column}
    FROM categories
    WHERE id = #{category_id}
    SQL
  end

  it "should migrate the data properly" do
    upload1 = Fabricate(:upload)
    upload2 = Fabricate(:upload)
    category1 = Fabricate(:category)
    category2 = Fabricate(:category)

    DB.exec(<<~SQL)
    UPDATE categories
    SET logo_url = '#{upload1.url}', background_url = '#{upload2.url}'
    WHERE categories.id = #{category1.id}
    SQL

    DB.exec(<<~SQL)
    UPDATE categories
    SET logo_url = '#{upload2.url}', background_url = '#{upload1.url}'
    WHERE categories.id = #{category2.id}
    SQL

    silence_stdout { described_class.new.up }

    expect(select_column_from_categories(:uploaded_logo_id, category1.id))
      .to eq(upload1.id)

    expect(select_column_from_categories(:uploaded_background_id, category1.id))
      .to eq(upload2.id)

    expect(select_column_from_categories(:uploaded_logo_id, category2.id))
      .to eq(upload2.id)

    expect(select_column_from_categories(:uploaded_background_id, category2.id))
      .to eq(upload1.id)
  end
end
