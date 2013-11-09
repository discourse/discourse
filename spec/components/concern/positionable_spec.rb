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

      # this is somewhat odd, but when there is not positioning
      # not much we can do
      TestItem.find(1).move_to(5)
      positions.should == [0,3,2,4,1]

      TestItem.pluck(:position).sort.should == [0,1,2,3,4]

      item = TestItem.new
      item.id = 7
      item.save
      item.position.should == 5
    end
  end
end
