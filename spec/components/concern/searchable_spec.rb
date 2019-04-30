# frozen_string_literal: true

require "rails_helper"

describe Searchable do
  context "has search data" do
    before do
      DB.exec("create temporary table searchable_records(id SERIAL primary key)")
      DB.exec("create temporary table searchable_record_search_data(searchable_record_id int primary key, search_data tsvector, raw_data text, locale text)")

      class SearchableRecord < ActiveRecord::Base
        include Searchable
      end

      class SearchableRecordSearchData < ActiveRecord::Base
        self.primary_key = 'searchable_record_id'
        belongs_to :test_item
      end
    end

    after do
      DB.exec("drop table searchable_records")
      DB.exec("drop table searchable_record_search_data")

      # this weakref in the descendant tracker should clean up the two tests
      # if this becomes an issue we can revisit (watch out for erratic tests)
      Object.send(:remove_const, :SearchableRecord)
      Object.send(:remove_const, :SearchableRecordSearchData)
    end

    let(:item) { SearchableRecord.create! }

    it 'can build the data' do
      expect(item.build_searchable_record_search_data).to be_truthy
    end

    it 'can save the data' do
      item.build_searchable_record_search_data(
        search_data: '',
        raw_data: 'a',
        locale: 'en')
      item.save

      loaded = SearchableRecord.find(item.id)
      expect(loaded.searchable_record_search_data.raw_data).to eq 'a'
    end

    it 'destroy the search data when the item is deprived' do
      item.build_searchable_record_search_data(
        search_data: '',
        raw_data: 'a',
        locale: 'en')
      item.save
      item_id = item.id
      item.destroy
      expect(SearchableRecordSearchData.find_by(searchable_record_id: item_id)).to be_nil
    end
  end
end
