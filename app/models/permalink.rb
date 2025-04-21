# frozen_string_literal: true

class Permalink < ActiveRecord::Base
  belongs_to :topic
  belongs_to :post
  belongs_to :category
  belongs_to :tag
  belongs_to :user

  before_validation :normalize_url, :encode_url

  validates :url, uniqueness: true
  validate :exactly_one_association

  class Normalizer
    attr_reader :source

    def initialize(source)
      @source = source
      @rules = source.split("|").map { |rule| parse_rule(rule) }.compact if source.present?
    end

    def parse_rule(rule)
      return unless rule =~ %r{/.*/}

      escaping = false
      regex = +""
      sub = +""
      c = 0

      rule.chars.each do |l|
        c += 1 if !escaping && l == "/"
        escaping = l == "\\"

        if c > 1
          sub << l
        else
          regex << l
        end
      end

      [Regexp.new(regex[1..-1]), sub[1..-1] || ""] if regex.length > 1
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
      url = url[1..-1] if url[0, 1] == "/"
    end

    normalizations = SiteSetting.permalink_normalizations

    @normalizer = Normalizer.new(normalizations) unless @normalizer &&
      @normalizer.source == normalizations
    @normalizer.normalize(url)
  end

  def self.find_by_url(url)
    find_by(url: normalize_url(url))
  end

  def target_url
    return relative_external_url if external_url
    return post.relative_url if post
    return topic.relative_url if topic
    return category.relative_url if category
    return tag.relative_url if tag
    return user.relative_url if user
    nil
  end

  def self.filter_by(url = nil)
    permalinks =
      Permalink.includes(:topic, :post, :category, :tag, :user).order("permalinks.created_at desc")

    permalinks.where!("url ILIKE :url OR external_url ILIKE :url", url: "%#{url}%") if url.present?
    permalinks.limit!(100)
    permalinks.to_a
  end

  private

  def normalize_url
    self.url = Permalink.normalize_url(url) if url
  end

  def encode_url
    self.url = UrlHelper.encode(url) if url
  end

  def relative_external_url
    external_url.match?(%r{\A/[^/]}) ? "#{Discourse.base_path}#{external_url}" : external_url
  end

  def exactly_one_association
    associations = [topic_id, post_id, category_id, tag_id, user_id, external_url]
    if associations.compact.size != 1
      errors.add(
        :base,
        "Exactly one of topic_id, post_id, category_id, tag_id, user_id, or external_url must be set",
      )
    end
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
#  tag_id       :integer
#  user_id      :integer
#
# Indexes
#
#  index_permalinks_on_url  (url) UNIQUE
#
