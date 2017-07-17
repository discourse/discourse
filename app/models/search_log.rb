require_dependency 'enum'

class SearchLog < ActiveRecord::Base
  validates_presence_of :term, :ip_address

  def self.search_types
    @search_types ||= Enum.new(
      header: 1,
      full_page: 2
    )
  end

  def self.log(term:, search_type:, ip_address:, user_id:nil)

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

  def self.clean_up
    search_id = SearchLog.order(:id).offset(SiteSetting.search_query_log_max_size).limit(1).pluck(:id)
    if search_id.present?
      SearchLog.where('id < ?', search_id[0]).delete_all
    end
  end
end
