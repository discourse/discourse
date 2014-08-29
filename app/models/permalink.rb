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
    return post.url if post
    return topic.relative_url if topic
    return category.url if category
    nil
  end
end
