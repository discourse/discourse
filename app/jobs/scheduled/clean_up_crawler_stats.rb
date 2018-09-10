module Jobs

  class CleanUpCrawlerStats < Jobs::Scheduled
    every 1.day

    def execute(args)
      WebCrawlerRequest.where('date < ?', WebCrawlerRequest.max_record_age.ago).delete_all

      # keep count of only the top user agents
      DB.exec <<~SQL
        WITH ranked_requests AS (
          SELECT row_number() OVER (ORDER BY count DESC) as row_number, id
            FROM web_crawler_requests
           WHERE date = '#{1.day.ago.strftime("%Y-%m-%d")}'
        )
        DELETE FROM web_crawler_requests
        WHERE id IN (
          SELECT ranked_requests.id
            FROM ranked_requests
           WHERE row_number > #{WebCrawlerRequest.max_records_per_day}
        )
      SQL
    end
  end

end
