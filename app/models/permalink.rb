# frozen_string_literal: true

class Permalink < ActiveRecord::Base
  attr_accessor :permalink_type, :permalink_type_value

  belongs_to :topic
  belongs_to :post
  belongs_to :category
  belongs_to :tag
  belongs_to :user

  before_validation :clear_associations
  before_validation :normalize_url, :encode_url
  before_validation :set_association_value

  validates :url, uniqueness: true

  validates :topic_id, presence: true, if: Proc.new { |permalink| permalink.topic_type? }
  validates :post_id, presence: true, if: Proc.new { |permalink| permalink.post_type? }
  validates :category_id, presence: true, if: Proc.new { |permalink| permalink.category_type? }
  validates :tag_id, presence: true, if: Proc.new { |permalink| permalink.tag_type? }
  validates :user_id, presence: true, if: Proc.new { |permalink| permalink.user_type? }
  validates :external_url, presence: true, if: Proc.new { |permalink| permalink.external_url_type? }

  %i[topic post category tag user external_url].each do |association|
    define_method("#{association}_type?") { self.permalink_type == association.to_s }
  end

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

  def clear_associations
    self.topic_id = nil
    self.post_id = nil
    self.category_id = nil
    self.user_id = nil
    self.tag_id = nil
    self.external_url = nil
  end

  def set_association_value
    self.topic_id = self.permalink_type_value if self.topic_type?
    self.post_id = self.permalink_type_value if self.post_type?
    self.user_id = self.permalink_type_value if self.user_type?
    self.category_id = self.permalink_type_value if self.category_type?
    self.external_url = self.permalink_type_value if self.external_url_type?
    self.tag_id = Tag.where(name: self.permalink_type_value).first&.id if self.tag_type?
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
