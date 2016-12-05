module DiscourseFeaturedLink
  CUSTOM_FIELD_NAME = 'featured_link'.freeze

  AdminDashboardData::GLOBAL_REPORTS << CUSTOM_FIELD_NAME

  Report.add_report(CUSTOM_FIELD_NAME) do |report|
    report.data = []
    link_topics = TopicCustomField.where(name: CUSTOM_FIELD_NAME)
    link_topics = link_topics.joins(:topic).where("topics.category_id = ?", report.category_id) if report.category_id
    link_topics.where("topic_custom_fields.created_at >= ?", report.start_date)
               .where("topic_custom_fields.created_at <= ?", report.end_date)
               .group("DATE(topic_custom_fields.created_at)")
               .order("DATE(topic_custom_fields.created_at)")
               .count
               .each { |date, count| report.data << { x: date, y: count } }
    report.total = link_topics.count
    report.prev30Days = link_topics.where("topic_custom_fields.created_at >= ?", report.start_date - 30.days)
                                   .where("topic_custom_fields.created_at <= ?", report.start_date)
                                   .count
  end

  def self.cache_onebox_link(link)
    # If the link is pasted swiftly, onebox may not have time to cache it
    Oneboxer.onebox(link, invalidate_oneboxes: false)
    link
  end
end
