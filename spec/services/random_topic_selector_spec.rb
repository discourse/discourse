require 'spec_helper'

describe RandomTopicSelector do

  it 'can correctly use cache' do
    key = RandomTopicSelector.cache_key

    $redis.del key

    4.times do |t|
      $redis.rpush key, t
    end

    RandomTopicSelector.next(2).should == [0,1]
    RandomTopicSelector.next(2).should == [2,3]
  end

  it 'can correctly backfill' do
    category = Fabricate(:category)
    t1 = Fabricate(:topic, category_id: category.id)
    _t2 = Fabricate(:topic, category_id: category.id, visible: false)
    _t3 = Fabricate(:topic, category_id: category.id, deleted_at: 1.minute.ago)
    t4 = Fabricate(:topic, category_id: category.id)

    RandomTopicSelector.next(5, category).sort.should == [t1.id,t4.id].sort
  end
end
