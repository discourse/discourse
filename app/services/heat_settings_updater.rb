# frozen_string_literal: true

class HeatSettingsUpdater
  def self.update
    return unless SiteSetting.automatic_topic_heat_values

    views_by_percentile = views_thresholds
    update_setting(:topic_views_heat_high, views_by_percentile[10])
    update_setting(:topic_views_heat_medium, views_by_percentile[25])
    update_setting(:topic_views_heat_low, views_by_percentile[45])

    like_ratios_by_percentile = like_ratio_thresholds
    update_setting(:topic_post_like_heat_high, like_ratios_by_percentile[10])
    update_setting(:topic_post_like_heat_medium, like_ratios_by_percentile[25])
    update_setting(:topic_post_like_heat_low, like_ratios_by_percentile[45])
  end

  def self.views_thresholds
    results = DB.query(<<~SQL)
      SELECT ranked.bucket * 5 as percentile, MIN(ranked.views) as views
      FROM (
        SELECT NTILE(20) OVER (ORDER BY t.views DESC) AS bucket, t.views
        FROM (
          SELECT views
            FROM topics
           WHERE deleted_at IS NULL
             AND archetype <> 'private_message'
             AND visible = TRUE
        ) t
      ) ranked
      WHERE bucket <= 9
      GROUP BY bucket
    SQL

    results.inject({}) do |h, row|
      h[row.percentile] = row.views
      h
    end
  end

  def self.like_ratio_thresholds
    results = DB.query(<<~SQL)
      SELECT ranked.bucket * 5 as percentile, MIN(ranked.ratio) as like_ratio
      FROM (
        SELECT NTILE(20) OVER (ORDER BY t.ratio DESC) AS bucket, t.ratio
        FROM (
          SELECT like_count::decimal / posts_count AS ratio
            FROM topics
           WHERE deleted_at IS NULL
             AND archetype <> 'private_message'
             AND visible = TRUE
             AND posts_count >= 10
             AND like_count > 0
        ORDER BY created_at DESC
           LIMIT 1000
        ) t
      ) ranked
      WHERE bucket <= 9
      GROUP BY bucket
    SQL

    results.inject({}) do |h, row|
      h[row.percentile] = row.like_ratio
      h
    end
  end

  def self.update_setting(name, new_value)
    if new_value.nil? || new_value <= SiteSetting.defaults[name]
      if SiteSetting.get(name) != SiteSetting.defaults[name]
        SiteSetting.set_and_log(name, SiteSetting.defaults[name])
      end
    elsif SiteSetting.get(name) == 0 ||
      (new_value.to_f / SiteSetting.get(name) - 1.0).abs >= 0.05

      rounded_new_value = if new_value.is_a?(Integer)
        if new_value > 9
          digits = new_value.digits.reverse
          (digits[0] * 10 + digits[1]) * 10.pow(digits[2..-1].size)
        else
          new_value
        end
      else
        new_value.round(2)
      end

      if SiteSetting.get(name) != rounded_new_value
        SiteSetting.set_and_log(name, rounded_new_value)
      end
    end
  end
end
