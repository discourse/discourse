class TopLists
  include ActiveModel::Serialization

  attr_accessor :draft, :draft_key, :draft_sequence

  TopTopic.periods.each { |period| attr_accessor period }
end
