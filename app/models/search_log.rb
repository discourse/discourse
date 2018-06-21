require_dependency 'enum'

class SearchLog < ActiveRecord::Base
  validates_presence_of :term

  def self.search_types
    @search_types ||= Enum.new(
      header: 1,
      full_page: 2
    )
  end

  def self.search_result_types
    @search_result_types ||= Enum.new(
      topic: 1,
      user: 2,
      category: 3,
      tag: 4
    )
  end

  def self.redis_key(ip_address:, user_id: nil)
    if user_id
      "__SEARCH__LOG_#{user_id}"
    else
      "__SEARCH__LOG_#{ip_address}"
    end
  end

  # for testing
  def self.clear_debounce_cache!
    $redis.keys("__SEARCH__LOG_*").each do |k|
      $redis.del(k)
    end
  end

  def self.log(term:, search_type:, ip_address:, user_id: nil)

    return [:error] if term.blank?

    search_type = search_types[search_type]
    return [:error] unless search_type.present? && ip_address.present?

    ip_address = nil if user_id
    key = redis_key(user_id: user_id, ip_address: ip_address)

    result = nil

    if existing = $redis.get(key)
      id, old_term = existing.split(",", 2)

      if term.start_with?(old_term)
        where(id: id.to_i).update_all(
          created_at: Time.zone.now,
          term: term
        )

        result = [:updated, id.to_i]
      end
    end

    if !result
      log = self.create!(
        term: term,
        search_type: search_type,
        ip_address: ip_address,
        user_id: user_id
      )

      result = [:created, log.id]
    end

    $redis.setex(key, 5, "#{result[1]},#{term}")

    result
  end

  def self.term_details(term, period = :weekly, search_type = :all)
    details = []

    result = SearchLog.select("COUNT(*) AS count, created_at::date AS date")
      .where('term LIKE ?', term)
      .where('created_at > ?', start_of(period))

    result = result.where('search_type = ?', search_types[search_type]) if search_type == :header || search_type == :full_page
    result = result.where('search_result_id IS NOT NULL') if search_type == :click_through_only

    result.group(:term)
      .order("date")
      .group("date")
      .each do |record|
        details << { x: Date.parse(record['date'].to_s), y: record['count'] }
      end

    return {
      type: "search_log_term",
      title: I18n.t("search_logs.graph_title"),
      start_date: start_of(period),
      end_date: Time.zone.now,
      data: details,
      period: period.to_s
    }
  end

  def self.trending(period = :all, search_type = :all)
    result = SearchLog.select("term,
       COUNT(*) AS searches,
       SUM(CASE
               WHEN search_result_id IS NOT NULL THEN 1
               ELSE 0
           END) AS click_through,
       COUNT(DISTINCT ip_address) AS unique")
      .where('created_at > ?', start_of(period))

    result = result.where('search_type = ?', search_types[search_type]) unless search_type == :all
    result = result.group(:term)
      .order('COUNT(DISTINCT ip_address) DESC, COUNT(*) DESC')
      .limit(100).to_a
  end

  def self.start_of(period)
    case period
    when :yearly    then 1.year.ago
    when :monthly   then 1.month.ago
    when :quarterly then 3.months.ago
    when :weekly    then 1.week.ago
    when :daily     then 1.day.ago
    else 1000.years.ago
    end
  end

  def self.clean_up
    search_id = SearchLog.order(:id).offset(SiteSetting.search_query_log_max_size).limit(1).pluck(:id)
    if search_id.present?
      SearchLog.where('id < ?', search_id[0]).delete_all
    end
    SearchLog.where('created_at < TIMESTAMP ?', SiteSetting.search_query_log_max_retention_days.days.ago).delete_all
  end
end

# == Schema Information
#
# Table name: search_logs
#
#  id                 :integer          not null, primary key
#  term               :string           not null
#  user_id            :integer
#  ip_address         :inet
#  search_result_id   :integer
#  search_type        :integer          not null
#  created_at         :datetime         not null
#  search_result_type :integer
#
