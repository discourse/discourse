# frozen_string_literal: true

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

      DB.exec("create temporary table test_items(id int primary key, position int)")
    end

    after do
      DB.exec("drop table test_items")

      # this weakref in the descendant tracker should clean up the two tests
      # if this becomes an issue we can revisit (watch out for erratic tests)
      Object.send(:remove_const, :TestItem)
    end

    it "can position stuff correctly" do
      5.times do |i|
        DB.exec("insert into test_items(id,position) values(#{i}, #{i})")
      end

      expect(positions).to eq([0, 1, 2, 3, 4])
      TestItem.find(3).move_to(0)
      expect(positions).to eq([3, 0, 1, 2, 4])
      expect(TestItem.pluck(:position).sort).to eq([0, 1, 2, 3, 4])

      TestItem.find(3).move_to(1)
      expect(positions).to eq([0, 3, 1, 2, 4])

      # this is somewhat odd, but when there is no such position, not much we can do
      TestItem.find(1).move_to(5)
      expect(positions).to eq([0, 3, 2, 4, 1])

      expect(TestItem.pluck(:position).sort).to eq([0, 1, 2, 3, 4])

      item = TestItem.new
      item.id = 7
      item.save
      expect(item.position).to eq(5)
    end
  end
end
