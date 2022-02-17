# frozen_string_literal: true

require "rails_helper"

describe HasCustomFields do
  context "custom_fields" do
    before do
      DB.exec("create temporary table custom_fields_test_items(id SERIAL primary key)")
      DB.exec("create temporary table custom_fields_test_item_custom_fields(id SERIAL primary key, custom_fields_test_item_id int, name varchar(256) not null, value text, created_at TIMESTAMP, updated_at TIMESTAMP)")
      DB.exec(<<~SQL)
        CREATE UNIQUE INDEX ON custom_fields_test_item_custom_fields (custom_fields_test_item_id)
        WHERE NAME = 'rare'
      SQL

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

      # this weakref in the descendant tracker should clean up the two tests
      # if this becomes an issue we can revisit (watch out for erratic tests)
      Object.send(:remove_const, :CustomFieldsTestItem)
      Object.send(:remove_const, :CustomFieldsTestItemCustomField)
    end

    it "allows preloading of custom fields" do
      test_item = CustomFieldsTestItem.new
      CustomFieldsTestItem.preload_custom_fields([test_item], ["test_field"])
      expect(test_item.preloaded_custom_fields).to eq({ "test_field" => nil })
    end

    it "errors if a custom field is not preloaded" do
      test_item = CustomFieldsTestItem.new
      CustomFieldsTestItem.preload_custom_fields([test_item], ["test_field"])
      expect { test_item.custom_fields["other_field"] }.to raise_error(HasCustomFields::NotPreloadedError)
    end

    it "resets the preloaded_custom_fields if preload_custom_fields is called twice" do
      test_item = CustomFieldsTestItem.new
      CustomFieldsTestItem.preload_custom_fields([test_item], ["test_field"])
      CustomFieldsTestItem.preload_custom_fields([test_item], ["other_field"])
      expect(test_item.preloaded_custom_fields).to eq({ "other_field" => nil })
    end

    it "does not error with NotPreloadedError if preload_custom_fields is called twice" do
      test_item = CustomFieldsTestItem.new
      CustomFieldsTestItem.preload_custom_fields([test_item], ["test_field"])
      expect { test_item.custom_fields["test_field"] }.not_to raise_error
      CustomFieldsTestItem.preload_custom_fields([test_item], ["other_field"])
      expect { test_item.custom_fields["other_field"] }.not_to raise_error
    end

    it "allows simple modification of custom fields" do
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

    it "reloads from the database" do
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

    it "actually saves on double save" do
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

    it "deletes nil-filled arrays" do
      test_item = CustomFieldsTestItem.create!
      db_item = CustomFieldsTestItem.find(test_item.id)

      db_item.custom_fields.update("a" => [nil, nil])
      db_item.save_custom_fields
      db_item.custom_fields.delete("a")
      expect(db_item.custom_fields).to eq({})

      db_item.save_custom_fields
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

    it "supports type coercion" do
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

    it "doesn't allow simple modifications to interfere" do
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

    it "supports arrays in json fields" do
      field_type = "json_array"
      CustomFieldsTestItem.register_custom_field_type(field_type, :json)

      item = CustomFieldsTestItem.new
      item.custom_fields = {
        "json_array" => [{ a: "test" }, { b: "another" }]
      }
      item.save

      item.reload

      expect(item.custom_fields[field_type]).to eq(
        [{ "a" => "test" }, { "b" => "another" }]
      )

      item.custom_fields["json_array"] = ['a', 'b']
      item.save

      item.reload

      expect(item.custom_fields[field_type]).to eq(["a", "b"])
    end

    it "will not fail to load custom fields if json is corrupt" do
      field_type = "bad_json"
      CustomFieldsTestItem.register_custom_field_type(field_type, :json)

      item = CustomFieldsTestItem.create!

      CustomFieldsTestItemCustomField.create!(
        custom_fields_test_item_id: item.id,
        name: field_type,
        value: "{test"
      )

      item = item.reload
      expect(item.custom_fields[field_type]).to eq({})
    end

    it "supports bulk retrieval with a list of ids" do
      item1 = CustomFieldsTestItem.new
      item1.custom_fields = { "a" => ["b", "c", "d"], 'not_allowlisted' => 'secret' }
      item1.save

      item2 = CustomFieldsTestItem.new
      item2.custom_fields = { "e" => 'hallo' }
      item2.save

      fields = CustomFieldsTestItem.custom_fields_for_ids([item1.id, item2.id], ['a', 'e'])
      expect(fields).to be_present
      expect(fields[item1.id]['a']).to match_array(['b', 'c', 'd'])
      expect(fields[item1.id]['not_allowlisted']).to be_blank
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

    describe "create_singular" do
      it "creates new records" do
        item = CustomFieldsTestItem.create!
        item.create_singular('hello', 'world')
        expect(item.reload.custom_fields['hello']).to eq('world')
      end

      it "upserts on a database constraint error" do
        item0 = CustomFieldsTestItem.new
        item0.custom_fields = { "rare" => "gem" }
        item0.save
        expect(item0.reload.custom_fields['rare']).to eq("gem")

        item0.create_singular('rare', "diamond")
        expect(item0.reload.custom_fields['rare']).to eq("diamond")
      end
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

      it 'allows upsert to use keywords' do
        test_item = CustomFieldsTestItem.create
        test_item.upsert_custom_fields(hello: 'world', abc: 'def')

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

      it 'allows using string and symbol indices interchangeably' do
        test_item = CustomFieldsTestItem.new

        test_item.custom_fields["bob"] = "marley"
        test_item.custom_fields["jack"] = "black"

        # In memory
        expect(test_item.custom_fields[:bob]).to eq('marley')
        expect(test_item.custom_fields[:jack]).to eq('black')

        # Persisted
        test_item.save
        test_item.reload
        expect(test_item.custom_fields[:bob]).to eq('marley')
        expect(test_item.custom_fields[:jack]).to eq('black')

        # Update via string index again
        test_item.custom_fields['bob'] = 'the builder'

        expect(test_item.custom_fields[:bob]).to eq('the builder')
        test_item.save
        test_item.reload

        expect(test_item.custom_fields[:bob]).to eq('the builder')
      end
    end
  end
end
