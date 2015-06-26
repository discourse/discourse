module Jobs
  class DailyPerformanceReport < Jobs::Scheduled
    every 1.day
    per_host

    def execute(args)
      if SiteSetting.daily_performance_report
        result = `ruby #{Rails.root}/script/nginx_analyze.rb --limit 1440`
        if result.strip.empty?
          result = "Report is only available in latest image, please run: \n\n cd /var/discourse && ./launcher rebuild app"
        end
        report_data = "```text\n#{result}\n```"

        PostCreator.create(Discourse.system_user,
                      topic_id: performance_topic_id,
                      raw: report_data,
                      skip_validations: true)

      end
    end

    def performance_topic_id

      if SiteSetting.performance_report_topic_id > 0
        topic = Topic.find_by(id: SiteSetting.performance_report_topic_id)
        return topic.id if topic
      end

      staff_category = Category.find_by(id: SiteSetting.staff_category_id)
      raise StandardError, "Staff category was not found" unless staff_category

      post = PostCreator.create(Discourse.system_user,
                           raw: I18n.t('performance_report.initial_post_raw'),
                           category: staff_category.name,
                           title: I18n.t('performance_report.initial_topic_title'),
                           skip_validations: true)


      unless post && post.topic_id
        raise StandardError, "Could not create or retrieve performance report topic id"
      end

      SiteSetting.performance_report_topic_id = post.topic_id

    end

  end
end
