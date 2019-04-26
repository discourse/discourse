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

  it "should migrate the data properly" do
    upload1 = Fabricate(:upload)
    upload2 = Fabricate(:upload)

    category1 = Fabricate(:category,
      logo_url: upload1.url,
      background_url: upload2.url
    )

    category2 = Fabricate(:category,
      logo_url: upload2.url,
      background_url: upload1.url
    )

    silence_stdout { described_class.new.up }

    Discourse.reset_active_record_cache

    category1.reload

    expect(category1.uploaded_logo_id).to eq(upload1.id)
    expect(category1.uploaded_background_id).to eq(upload2.id)

    category2.reload

    expect(category2.uploaded_logo_id).to eq(upload2.id)
    expect(category2.uploaded_background_id).to eq(upload1.id)
  end
end
