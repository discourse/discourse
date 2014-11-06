class Permalink < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  belongs_to :category

  before_validation :normalize_url

  def normalize_url
    if self.url
      self.url = self.url.strip
      self.url = self.url[1..-1] if url[0,1] == '/'
    end
  end

  def target_url
    return external_url if external_url
    return post.url if post
    return topic.relative_url if topic
    return category.url if category
    nil
  end
end

# == Schema Information
#
# Table name: permalinks
#
#  id           :integer          not null, primary key
#  url          :string(1000)     not null
#  topic_id     :integer
#  post_id      :integer
#  category_id  :integer
#  created_at   :datetime
#  updated_at   :datetime
#  external_url :string(1000)
#
# Indexes
#
#  index_permalinks_on_url  (url) UNIQUE
#
