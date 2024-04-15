# frozen_string_literal: true

class SearchSortOrderSiteSetting < EnumSiteSetting
  def self.valid_value?(val)
    val.to_i.to_s == val.to_s && values.any? { |v| v[:value] == val.to_i }
  end

  def self.values
    @values ||= [
      { name: "search.relevance", value: 0, id: :relevance },
      { name: "search.latest_post", value: 1, id: :latest },
      { name: "search.most_liked", value: 2, id: :likes },
      { name: "search.most_viewed", value: 3, id: :views },
      { name: "search.latest_topic", value: 4, id: :latest_topic },
    ]
  end

  def self.value_from_id(id)
    values.find { |v| v[:id] == id }[:value]
  end

  def self.id_from_value(value)
    values.find { |v| v[:value] == value }[:id]
  end

  def self.translate_names?
    true
  end
end
