require "rails_helper"

describe HasCustomFields do

  context "custom_fields" do
    before do
      DB.exec("create temporary table custom_fields_test_items(id SERIAL primary key)")
      DB.exec("create temporary table custom_fields_test_item_custom_fields(id SERIAL primary key, custom_fields_test_item_id int, name varchar(256) not null, value text)")

      class CustomFieldsTestItem < ActiveRecord::Base
        include HasCustomFields
      end

      class CustomFieldsTestItemCustomField < ActiveRecord::Base
        belongs_to :custom_fields_test_item
      end
    end

    after do
      DB.exec("drop table custom_fields_test_items")
      DB.exec("drop table custom_fields_test_item_custom_fields")

      # import is making my life hard, we need to nuke this out of orbit
      des = ActiveSupport::DescendantsTracker.class_variable_get :@@direct_descendants
      des[ActiveRecord::Base].delete(CustomFieldsTestItem)
      des[ActiveRecord::Base].delete(CustomFieldsTestItemCustomField)
    end

    it "simple modification of custom fields" do
      test_item = CustomFieldsTestItem.new

      expect(test_item.custom_fields["a"]).to eq(nil)

      test_item.custom_fields["bob"] = "marley"
      test_item.custom_fields["jack"] = "black"

      test_item.save

      test_item = CustomFieldsTestItem.find(test_item.id)

      expect(test_item.custom_fields["bob"]).to eq("marley")
      expect(test_item.custom_fields["jack"]).to eq("black")

      test_item.custom_fields.delete("bob")
      test_item.custom_fields["jack"] = "jill"

      test_item.save
      test_item = CustomFieldsTestItem.find(test_item.id)

      expect(test_item.custom_fields).to eq("jack" => "jill")
    end

    it "casts integers to string without error" do
      test_item = CustomFieldsTestItem.new
      expect(test_item.custom_fields["a"]).to eq(nil)
      test_item.custom_fields["a"] = 0

      expect(test_item.custom_fields["a"]).to eq(0)
      test_item.save

      # should be casted right after saving
      expect(test_item.custom_fields["a"]).to eq("0")

      test_item = CustomFieldsTestItem.find(test_item.id)
      expect(test_item.custom_fields["a"]).to eq("0")
    end

    it "reload loads from database" do
      test_item = CustomFieldsTestItem.new
      test_item.custom_fields["a"] = 0

      expect(test_item.custom_fields["a"]).to eq(0)
      test_item.save

      # should be casted right after saving
      expect(test_item.custom_fields["a"]).to eq("0")

      DB.exec("UPDATE custom_fields_test_item_custom_fields SET value='1' WHERE custom_fields_test_item_id=? AND name='a'", test_item.id)

      # still the same, did not load
      expect(test_item.custom_fields["a"]).to eq("0")

      # refresh loads from database
      expect(test_item.reload.custom_fields["a"]).to eq("1")
      expect(test_item.custom_fields["a"]).to eq("1")
    end

    it "double save actually saves" do
      test_item = CustomFieldsTestItem.new
      test_item.custom_fields = { "a" => "b" }
      test_item.save

      test_item.custom_fields["c"] = "d"
      test_item.save

      db_item = CustomFieldsTestItem.find(test_item.id)
      expect(db_item.custom_fields).to eq("a" => "b", "c" => "d")
    end

    it "handles arrays properly" do

      CustomFieldsTestItem.register_custom_field_type "array", [:integer]
      test_item = CustomFieldsTestItem.new
      test_item.custom_fields = { "array" => ["1"] }
      test_item.save

      db_item = CustomFieldsTestItem.find(test_item.id)
      expect(db_item.custom_fields).to eq("array" => [1])

      test_item = CustomFieldsTestItem.new
      test_item.custom_fields = { "a" => ["b", "c", "d"] }
      test_item.save

      db_item = CustomFieldsTestItem.find(test_item.id)
      expect(db_item.custom_fields).to eq("a" => ["b", "c", "d"])

      db_item.custom_fields.update('a' => ['c', 'd'])
      db_item.save
      expect(db_item.custom_fields).to eq("a" => ["c", "d"])

      # It can be updated to the exact same value
      db_item.custom_fields.update('a' => ['c'])
      db_item.save
      expect(db_item.custom_fields).to eq("a" => "c")
      db_item.custom_fields.update('a' => ['c'])
      db_item.save
      expect(db_item.custom_fields).to eq("a" => "c")

      db_item.custom_fields.delete('a')
      expect(db_item.custom_fields).to eq({})
    end

    it "casts integers in arrays properly without error" do
      test_item = CustomFieldsTestItem.new
      test_item.custom_fields = { "a" => ["b", 10, "d"] }
      test_item.save
      expect(test_item.custom_fields).to eq("a" => ["b", "10", "d"])

      db_item = CustomFieldsTestItem.find(test_item.id)
      expect(db_item.custom_fields).to eq("a" => ["b", "10", "d"])
    end

    it "supportes type coersion" do
      test_item = CustomFieldsTestItem.new
      CustomFieldsTestItem.register_custom_field_type("bool", :boolean)
      CustomFieldsTestItem.register_custom_field_type("int", :integer)
      CustomFieldsTestItem.register_custom_field_type("json", :json)

      test_item.custom_fields = { "bool" => true, "int" => 1, "json" => { "foo" => "bar" } }
      test_item.save
      test_item.reload

      expect(test_item.custom_fields).to eq("bool" => true, "int" => 1, "json" => { "foo" => "bar" })

      before_ids = CustomFieldsTestItemCustomField.where(custom_fields_test_item_id: test_item.id).pluck(:id)

      test_item.custom_fields["bool"] = false
      test_item.save

      after_ids = CustomFieldsTestItemCustomField.where(custom_fields_test_item_id: test_item.id).pluck(:id)

      # we updated only 1 custom field, so there should be only 1 different id
      expect((before_ids - after_ids).size).to eq(1)
    end

    it "simple modifications don't interfere" do
      test_item = CustomFieldsTestItem.new

      expect(test_item.custom_fields["a"]).to eq(nil)

      test_item.custom_fields["bob"] = "marley"
      test_item.custom_fields["jack"] = "black"
      test_item.save

      test_item2 = CustomFieldsTestItem.new

      expect(test_item2.custom_fields["x"]).to eq(nil)

      test_item2.custom_fields["sixto"] = "rodriguez"
      test_item2.custom_fields["de"] = "la playa"
      test_item2.save

      test_item = CustomFieldsTestItem.find(test_item.id)
      test_item2 = CustomFieldsTestItem.find(test_item2.id)

      expect(test_item.custom_fields).to eq("jack" => "black", "bob" => "marley")
      expect(test_item2.custom_fields).to eq("sixto" => "rodriguez", "de" => "la playa")
    end

    it "supports bulk retrieval with a list of ids" do
      item1 = CustomFieldsTestItem.new
      item1.custom_fields = { "a" => ["b", "c", "d"], 'not_whitelisted' => 'secret' }
      item1.save

      item2 = CustomFieldsTestItem.new
      item2.custom_fields = { "e" => 'hallo' }
      item2.save

      fields = CustomFieldsTestItem.custom_fields_for_ids([item1.id, item2.id], ['a', 'e'])
      expect(fields).to be_present
      expect(fields[item1.id]['a']).to match_array(['b', 'c', 'd'])
      expect(fields[item1.id]['not_whitelisted']).to be_blank
      expect(fields[item2.id]['e']).to eq('hallo')
    end

    it "handles interleaving saving properly" do
      field_type = 'deep-nest-test'
      CustomFieldsTestItem.register_custom_field_type(field_type, :json)
      test_item = CustomFieldsTestItem.create!

      test_item.custom_fields[field_type] ||= {}
      test_item.custom_fields[field_type]['b'] ||= {}
      test_item.custom_fields[field_type]['b']['c'] = 'd'
      test_item.save_custom_fields(true)

      db_item = CustomFieldsTestItem.find(test_item.id)
      db_item.custom_fields[field_type]['b']['e'] = 'f'
      test_item.custom_fields[field_type]['b']['e'] = 'f'
      expected = { field_type => { 'b' => { 'c' => 'd', 'e' => 'f' } } }

      db_item.save_custom_fields(true)
      expect(db_item.reload.custom_fields).to eq(expected)

      test_item.save_custom_fields(true)
      expect(test_item.reload.custom_fields).to eq(expected)
    end

    describe "upsert_custom_fields" do
      it 'upserts records' do
        test_item = CustomFieldsTestItem.create
        test_item.upsert_custom_fields('hello' => 'world', 'abc' => 'def')

        # In memory
        expect(test_item.custom_fields['hello']).to eq('world')
        expect(test_item.custom_fields['abc']).to eq('def')

        # Persisted
        test_item.reload
        expect(test_item.custom_fields['hello']).to eq('world')
        expect(test_item.custom_fields['abc']).to eq('def')

        # In memory
        test_item.upsert_custom_fields('abc' => 'ghi')
        expect(test_item.custom_fields['hello']).to eq('world')
        expect(test_item.custom_fields['abc']).to eq('ghi')

        # Persisted
        test_item.reload
        expect(test_item.custom_fields['hello']).to eq('world')
        expect(test_item.custom_fields['abc']).to eq('ghi')
      end
    end
  end
end
