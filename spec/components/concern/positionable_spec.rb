require "rails_helper"

describe Positionable do

  def positions
    TestItem.order('position asc, id asc').pluck(:id)
  end

  context "move_to" do
    before do
      class TestItem < ActiveRecord::Base
        include Positionable
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

      expect(positions).to eq([0,1,2,3,4])
      TestItem.find(3).move_to(0)
      expect(positions).to eq([3,0,1,2,4])
      expect(TestItem.pluck(:position).sort).to eq([0,1,2,3,4])

      TestItem.find(3).move_to(1)
      expect(positions).to eq([0,3,1,2,4])

      # this is somewhat odd, but when there is no such position, not much we can do
      TestItem.find(1).move_to(5)
      expect(positions).to eq([0,3,2,4,1])

      expect(TestItem.pluck(:position).sort).to eq([0,1,2,3,4])

      item = TestItem.new
      item.id = 7
      item.save
      expect(item.position).to eq(5)
    end
  end
end
