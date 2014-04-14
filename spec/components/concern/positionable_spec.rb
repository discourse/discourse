require "spec_helper"
require_dependency "concern/positionable"

describe Concern::Positionable do

  def positions
    TestItem.order('position asc, id asc').pluck(:id)
  end

  context "move_to" do
    before do
      class TestItem < ActiveRecord::Base
        include Concern::Positionable
      end

      Topic.exec_sql("create temporary table test_items(id int primary key, position int)")
    end

    after do
      Topic.exec_sql("drop table test_items")

      # import is making my life hard, we need to nuke this out of orbit
      des = ActiveSupport::DescendantsTracker.class_variable_get :@@direct_descendants
      des[ActiveRecord::Base].delete(TestItem)
    end

    it "can position stuff correctly" do
      5.times do |i|
        Topic.exec_sql("insert into test_items(id,position) values(#{i}, #{i})")
      end

      positions.should == [0,1,2,3,4]
      TestItem.find(3).move_to(0)
      positions.should == [3,0,1,2,4]
      TestItem.pluck(:position).sort.should == [0,1,2,3,4]

      TestItem.find(3).move_to(1)
      positions.should == [0,3,1,2,4]

      # this is somewhat odd, but when there is no such position, not much we can do
      TestItem.find(1).move_to(5)
      positions.should == [0,3,2,4,1]

      TestItem.pluck(:position).sort.should == [0,1,2,3,4]

      item = TestItem.new
      item.id = 7
      item.save
      item.position.should be_nil
    end

    it "can set records to have null position" do
      5.times do |i|
        Topic.exec_sql("insert into test_items(id,position) values(#{i}, #{i})")
      end

      TestItem.find(2).use_default_position
      TestItem.find(2).position.should be_nil

      TestItem.find(1).move_to(4)
      TestItem.order('id ASC').pluck(:position).should == [0,4,nil,2,3]
    end

    it "can maintain null positions when moving things around" do
      5.times do |i|
        Topic.exec_sql("insert into test_items(id,position) values(#{i}, null)")
      end

      TestItem.find(2).move_to(0)
      TestItem.order('id asc').pluck(:position).should == [nil,nil,0,nil,nil]
      TestItem.find(0).move_to(4)
      TestItem.order('id asc').pluck(:position).should == [4,nil,0,nil,nil]
      TestItem.find(2).move_to(1)
      TestItem.order('id asc').pluck(:position).should == [4,nil,1,nil,nil]
      TestItem.find(0).move_to(1)
      TestItem.order('id asc').pluck(:position).should == [1,nil,2,nil,nil]
    end
  end
end
