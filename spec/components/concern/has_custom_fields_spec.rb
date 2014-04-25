require "spec_helper"
require_dependency "concern/has_custom_fields"

describe Concern::HasCustomFields do

  context "custom_fields" do
    before do

      Topic.exec_sql("create temporary table test_items(id SERIAL primary key)")
      Topic.exec_sql("create temporary table test_item_custom_fields(id SERIAL primary key, test_item_id int, name varchar(256) not null, value text)")

      class TestItem < ActiveRecord::Base
        include Concern::HasCustomFields
      end

      class TestItemCustomField < ActiveRecord::Base
        belongs_to :test_item
      end
    end

    after do
      Topic.exec_sql("drop table test_items")
      Topic.exec_sql("drop table test_item_custom_fields")

      # import is making my life hard, we need to nuke this out of orbit
      des = ActiveSupport::DescendantsTracker.class_variable_get :@@direct_descendants
      des[ActiveRecord::Base].delete(TestItem)
      des[ActiveRecord::Base].delete(TestItemCustomField)
    end

    it "simple modification of custom fields" do
      test_item = TestItem.new

      test_item.custom_fields["a"].should == nil

      test_item.custom_fields["bob"] = "marley"
      test_item.custom_fields["jack"] = "black"

      test_item.save

      test_item = TestItem.find(test_item.id)

      test_item.custom_fields["bob"].should == "marley"
      test_item.custom_fields["jack"].should == "black"

      test_item.custom_fields.delete("bob")
      test_item.custom_fields["jack"] = "jill"

      test_item.save
      test_item = TestItem.find(test_item.id)

      test_item.custom_fields.should == {"jack" => "jill"}
    end

    it "casts integers to string without error" do
      test_item = TestItem.new
      test_item.custom_fields["a"].should == nil
      test_item.custom_fields["a"] = 0

      test_item.custom_fields["a"].should == 0
      test_item.save

      # should be casted right after saving
      test_item.custom_fields["a"].should == "0"

      test_item = TestItem.find(test_item.id)
      test_item.custom_fields["a"].should == "0"
    end

    it "double save actually saves" do

      test_item = TestItem.new
      test_item.custom_fields = {"a" => "b"}
      test_item.save

      test_item.custom_fields["c"] = "d"
      test_item.save

      db_item = TestItem.find(test_item.id)
      db_item.custom_fields.should == {"a" => "b", "c" => "d"}

    end


    it "handles arrays properly" do

      test_item = TestItem.new
      test_item.custom_fields = {"a" => ["b", "c", "d"]}
      test_item.save

      db_item = TestItem.find(test_item.id)
      db_item.custom_fields.should == {"a" => ["b", "c", "d"]}

      db_item.custom_fields["a"] = ["c", "d"]
      db_item.save
      db_item.custom_fields.should == {"a" => ["c", "d"]}

    end

    it "casts integers in arrays properly without error" do

      test_item = TestItem.new
      test_item.custom_fields = {"a" => ["b", 10, "d"]}
      test_item.save
      test_item.custom_fields.should == {"a" => ["b", "10", "d"]}

      db_item = TestItem.find(test_item.id)
      db_item.custom_fields.should == {"a" => ["b", "10", "d"]}

    end

    it "simple modifications don't interfere" do
      test_item = TestItem.new

      test_item.custom_fields["a"].should == nil

      test_item.custom_fields["bob"] = "marley"
      test_item.custom_fields["jack"] = "black"
      test_item.save

      test_item2 = TestItem.new

      test_item2.custom_fields["x"].should == nil

      test_item2.custom_fields["sixto"] = "rodriguez"
      test_item2.custom_fields["de"] = "la playa"
      test_item2.save

      test_item = TestItem.find(test_item.id)
      test_item2 = TestItem.find(test_item2.id)

      test_item.custom_fields.should == {"jack" => "black", "bob" => "marley"}
      test_item2.custom_fields.should == {"sixto" => "rodriguez", "de" => "la playa"}
    end
  end
end
