require_dependency 'enum'

class SearchLog < ActiveRecord::Base
  validates_presence_of :term, :ip_address

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

  def self.log(term:, search_type:, ip_address:, user_id: nil)

    search_type = search_types[search_type]
    return [:error] unless search_type.present? && ip_address.present?

    update_sql = <<~SQL
      UPDATE search_logs
      SET term = :term,
        created_at = :created_at
      WHERE created_at > :timeframe AND
        position(term IN :term) = 1 AND
        ((:user_id IS NULL AND ip_address = :ip_address) OR
          (user_id = :user_id))
      RETURNING id
    SQL

    rows = exec_sql(
      update_sql,
      term: term,
      created_at: Time.zone.now,
      timeframe: 5.seconds.ago,
      user_id: user_id,
      ip_address: ip_address
    )

    if rows.cmd_tuples == 0
      result = create(
        term: term,
        search_type: search_type,
        ip_address: ip_address,
        user_id: user_id
      )
      [:created, result.id]
    else
      [:updated, rows[0]['id'].to_i]
    end
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
      data: details
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
  end
end

# == Schema Information
#
# Table name: search_logs
#
#  id                 :integer          not null, primary key
#  term               :string           not null
#  user_id            :integer
#  ip_address         :inet             not null
#  search_result_id   :integer
#  search_type        :integer          not null
#  created_at         :datetime         not null
#  search_result_type :integer
#
