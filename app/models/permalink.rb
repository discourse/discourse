class Permalink < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  belongs_to :category

  before_validation :normalize_url

  class Normalizer
    attr_reader :source

    def initialize(source)
      @source = source
      if source.present?
        @rules = source.split('|').map { |rule| parse_rule(rule) }.compact
      end
    end

    def parse_rule(rule)
      return unless rule =~ %r{\/.*\/}

      escaping = false
      regex = ''
      sub = ''
      c = 0

      rule.chars.each do |l|
        c += 1 if !escaping && l == '/'
        escaping = l == "\\"

        c > 1 ? sub << l : regex << l
      end

      [Regexp.new(regex[1..-1]), sub[1..-1] || ''] if regex.length > 1
    end

    def normalize(url)
      return url unless @rules
      @rules.each { |(regex, sub)| url = url.sub(regex, sub) }

      url
    end
  end

  def self.normalize_url(url)
    if url
      url = url.strip
      url = url[1..-1] if url[0, 1] == '/'
    end

    normalizations = SiteSetting.permalink_normalizations

    unless @normalizer && @normalizer.source == normalizations
      @normalizer = Normalizer.new(normalizations)
    end
    @normalizer.normalize(url)
  end

  def self.find_by_url(url)
    find_by(url: normalize_url(url))
  end

  def normalize_url
    self.url = Permalink.normalize_url(url) if url
  end

  def target_url
    return external_url if external_url
    return "#{Discourse.base_uri}#{post.url}" if post
    return topic.relative_url if topic
    return category.url if category
    nil
  end

  def self.filter_by(url = nil)
    permalinks =
      Permalink.includes(:topic, :post, :category).order(
        'permalinks.created_at desc'
      )

    if url.present?
      permalinks.where!(
        'url ILIKE :url OR external_url ILIKE :url',
        url: "%#{url}%"
      )
    end
    permalinks.limit!(100)
    permalinks.to_a
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
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  external_url :string(1000)
#
# Indexes
#
#  index_permalinks_on_url  (url) UNIQUE
#
