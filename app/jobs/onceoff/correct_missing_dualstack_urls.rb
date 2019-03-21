module Jobs
  class CorrectMissingDualstackUrls < Jobs::Onceoff
    def execute_onceoff(args)
      # s3 now uses dualstack urls, keep them around correctly
      # in both uploads and optimized_image tables
      base_url = Discourse.store.absolute_base_url

      return if !base_url.match?(/s3\.dualstack/)

      old = base_url.sub('s3.dualstack.', 's3-')
      old_like = "#{old}%"

      sql = <<~SQL
        UPDATE uploads
        SET url = replace(url, :from, :to)
        WHERE url ilike :old_like
      SQL
      DB.exec(sql, from: old, to: base_url, old_like: old_like)

      sql = <<~SQL
        UPDATE optimized_images
        SET url = replace(url, :from, :to)
        WHERE url ilike :old_like
      SQL
      DB.exec(sql, from: old, to: base_url, old_like: old_like)
    end
  end
end
