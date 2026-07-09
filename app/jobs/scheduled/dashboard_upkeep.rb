# frozen_string_literal: true

module Jobs
  # Demo-site only: keeps the admin dashboard tiles populated as the rolling
  # window moves forward. Re-derives topic/post/user dates into the window and
  # tops up visits, pageviews, topic views, likes and solutions. Every step is
  # idempotent and safe to re-run.
  class DashboardUpkeep < ::Jobs::Scheduled
    every 1.day

    SEED = 4242
    WINDOW_DAYS = 180
    RECENT_SHARE = 0.6
    LIKE_PROBABILITY = 0.4
    SOLUTION_SHARE = 0.15
    VIEWS_PER_TOPIC_DAY = 25
    TARGET_NEW_USERS = 60
    APPLICATION_REQUEST_BASELINE = 25_000
    TRUST_LEVEL_CHANGE_TARGET = 1_200
    SUPPORT_TOPIC_TARGET = 1_800
    SEARCH_SEED_USER_AGENT = "dashboard-upkeep-seed"
    PROTECTED_USERNAMES = %w[system discobot tomtom steak].freeze
    COUNTRY_TRAFFIC_SHARES = {
      "CN" => 0.62,
      "SG" => 0.17,
      "US" => 0.11,
      "IN" => 0.04,
      "AU" => 0.03,
      "GB" => 0.02,
      "DE" => 0.01,
    }.freeze
    REFERRER_TRAFFIC_SHARES = {
      nil => 0.43,
      "api.discourse.org" => 0.22,
      "meta.discourse.org" => 0.12,
      "google.com/search" => 0.09,
      "github.com/discourse" => 0.06,
      "news.ycombinator.com/item" => 0.05,
      "stackoverflow.com/questions" => 0.03,
    }.freeze
    SEARCH_TERM_PROFILES = [
      { term: "password reset", min: 120, max: 260, click_rate: 0.82 },
      { term: "video upload", min: 90, max: 220, click_rate: 0.76 },
      { term: "sso login", min: 80, max: 190, click_rate: 0.72 },
      { term: "api token", min: 75, max: 175, click_rate: 0.68 },
      { term: "troubleshooting", min: 95, max: 230, click_rate: 0.64 },
      { term: "markdown tables", min: 70, max: 170, click_rate: 0.14 },
      { term: "invoice export", min: 60, max: 145, click_rate: 0.0 },
      { term: "private category 字", min: 48, max: 120, click_rate: 0.08 },
      { term: "email notifications", min: 70, max: 165, click_rate: 0.7 },
      { term: "mobile app", min: 65, max: 150, click_rate: 0.62 },
      { term: "billing portal", min: 55, max: 135, click_rate: 0.12 },
      { term: "webhook retry", min: 45, max: 115, click_rate: 0.0 },
      { term: "oauth setup", min: 45, max: 110, click_rate: 0.58 },
      { term: "category permissions", min: 55, max: 130, click_rate: 0.5 },
      { term: "notification digest", min: 45, max: 105, click_rate: 0.66 },
      { term: "bulk invite csv", min: 35, max: 95, click_rate: 0.18 },
      { term: "theme component error", min: 35, max: 90, click_rate: 0.1 },
      { term: "audit export", min: 30, max: 80, click_rate: 0.0 },
    ].freeze
    FIXED_HOLIDAYS_MD = [
      [1, 1],
      [2, 14],
      [5, 1],
      [7, 4],
      [10, 31],
      [12, 24],
      [12, 25],
      [12, 26],
      [12, 31],
    ].to_set

    def execute(_args)
      setup
      rewrite_topic_and_post_dates
      promote_users_into_window
      rederive_user_dates
      backfill_user_stats
      seed_user_visits
      seed_application_requests
      seed_browser_pageview_rollups
      seed_search_logs
      seed_trust_level_pipeline_changes
      seed_topic_view_stats
      seed_likes
      seed_accepted_solutions
      seed_support_section_metrics
      log_summary
      clear_dashboard_cache
    end

    private

    def setup
      @rng = Random.new(SEED)
      @start_date = WINDOW_DAYS.days.ago.to_date
      @end_date = Date.current
      # dense "recent" bias spans the 3-month dashboard window + headroom, so the
      # boundary taper falls outside the view and the left edge fills cleanly.
      @recent_window_days = (Date.current - (Date.current << 3)).to_i + 10
      @started_at = Time.now

      @holidays = Set.new((@start_date.year..@end_date.year).map { |y| us_thanksgiving(y) })
      @spike_dates =
        Set.new.tap do |set|
          (@start_date..@end_date)
            .group_by { |d| [d.year, d.month] }
            .each_value do |days|
              next if days.size < 2
              i = @rng.rand(days.size - 1)
              set << days[i]
              set << days[i + 1]
            end
        end
      @mega_spike_date = (@start_date..@end_date).to_a.sample(random: @rng)
    end

    # --------------------------------------------------------------------------
    # TOPIC + POST DATE REWRITE  (biased recent, update_columns skips callbacks)
    # --------------------------------------------------------------------------
    def rewrite_topic_and_post_dates
      total_topics = Topic.where(archetype: "regular").count
      log "topic date rewrite — #{total_topics} regular topics"

      rewritten = 0
      Topic
        .where(archetype: "regular")
        .find_each do |topic|
          posts = Post.where(topic_id: topic.id).order(:post_number).to_a
          next if posts.empty?

          topic_at = biased_random_time
          topic.update_columns(created_at: topic_at, updated_at: topic_at)

          last_at = topic_at
          posts.each_with_index do |post, idx|
            next if post.action_code.present?
            reply_at = idx.zero? ? topic_at : last_at + @rng.rand(1..36).hours
            reply_at = Time.now if reply_at > Time.now
            post.update_columns(created_at: reply_at, updated_at: reply_at)
            last_at = reply_at
          end

          topic.update_columns(last_posted_at: last_at, bumped_at: last_at, updated_at: last_at)
          rewritten += 1
        rescue => e
          log "topic date rewrite #{topic.id}: #{e.message}"
        end
      log "topic/post dates rewritten: #{rewritten}/#{total_topics}"
    end

    # --------------------------------------------------------------------------
    # PROMOTE EXISTING USERS TO "NEW USERS + NEW CONTRIBUTORS"
    # No user creation — pick from the existing pool, reassign their old posts to
    # a donor, give them a recent topic, push their created_at into the window.
    # --------------------------------------------------------------------------
    def promote_users_into_window
      candidates =
        User
          .where("id > 0")
          .where(active: true)
          .where(admin: false)
          .where.not(username: PROTECTED_USERNAMES)
          .order("RANDOM()")
          .limit(TARGET_NEW_USERS)
          .to_a

      recent_topics =
        Topic
          .where(archetype: "regular")
          .where("created_at >= ?", 90.days.ago)
          .order("RANDOM()")
          .limit(TARGET_NEW_USERS)
          .to_a

      donor =
        User.find_by(username: "tomtom") || User.where(admin: true).where("id > 0").first ||
          Discourse.system_user
      log "promote: #{candidates.size} candidates, #{recent_topics.size} recent topics, donor=#{donor.username}"

      promoted = 0
      candidates
        .zip(recent_topics)
        .each do |user, topic|
          next unless topic

          Post.where(user_id: user.id).update_all(user_id: donor.id)
          Topic.where(user_id: user.id).update_all(user_id: donor.id, last_post_user_id: donor.id)

          op = Post.where(topic_id: topic.id).order(:post_number).first
          op.update_columns(user_id: user.id) if op
          topic.update_columns(user_id: user.id, last_post_user_id: user.id)

          new_at = topic.created_at - @rng.rand(1..72).hours
          user.update_columns(
            created_at: new_at,
            first_seen_at: new_at,
            last_seen_at: [topic.created_at, user.last_seen_at].max,
          )

          UserStat.where(user_id: user.id).update_all(first_post_created_at: topic.created_at)
          promoted += 1
        rescue => e
          log "promote skip user #{user.id}: #{e.message.lines.first}"
        end

      DB.exec(<<~SQL, donor_id: donor.id)
        UPDATE user_stats SET
          first_post_created_at = (SELECT MIN(created_at) FROM posts WHERE user_id = :donor_id),
          post_count            = (SELECT COUNT(*)        FROM posts WHERE user_id = :donor_id),
          topic_count           = (SELECT COUNT(DISTINCT topic_id) FROM posts WHERE user_id = :donor_id)
        WHERE user_id = :donor_id
      SQL
      log "promoted: #{promoted}/#{TARGET_NEW_USERS}"
    end

    # --------------------------------------------------------------------------
    # RE-DERIVE USER DATES FROM POSTS  (defense-in-depth)
    # --------------------------------------------------------------------------
    def rederive_user_dates
      DB.exec(<<~SQL)
        UPDATE users
        SET created_at = LEAST(users.created_at, p.first_post),
            first_seen_at = LEAST(COALESCE(users.first_seen_at, users.created_at), p.first_post),
            last_seen_at = GREATEST(COALESCE(users.last_seen_at, users.created_at), p.last_post)
        FROM (
          SELECT user_id, MIN(created_at) AS first_post, MAX(created_at) AS last_post
          FROM posts WHERE user_id > 0 GROUP BY user_id
        ) p
        WHERE users.id = p.user_id
      SQL
      log "user dates re-derived from posts"
    end

    # --------------------------------------------------------------------------
    # USER_STATS BACKFILL  (post_count, topic_count, first_post_created_at)
    # --------------------------------------------------------------------------
    def backfill_user_stats
      DB.exec(<<~SQL)
        UPDATE user_stats
        SET first_post_created_at = p.first_post
        FROM (
          SELECT user_id, MIN(created_at) AS first_post
          FROM posts WHERE user_id > 0 GROUP BY user_id
        ) p
        WHERE user_stats.user_id = p.user_id
      SQL

      DB.exec(<<~SQL)
        UPDATE user_stats
        SET post_count = sub.cnt,
            topic_count = sub.topic_cnt
        FROM (
          SELECT user_id, COUNT(*) AS cnt, COUNT(DISTINCT topic_id) AS topic_cnt
          FROM posts WHERE user_id > 0 GROUP BY user_id
        ) sub
        WHERE user_stats.user_id = sub.user_id
      SQL
      log "user_stats backfilled"
    end

    # --------------------------------------------------------------------------
    # USER VISITS  (DAU/MAU; 30-day pre-window for MAU)
    # --------------------------------------------------------------------------
    def seed_user_visits
      visit_pool = User.where("id > 0").where(active: true).to_a
      ((@start_date - 30.days)..@end_date).each do |date|
        share = (0.08 + @rng.rand * 0.06) * day_factor(date)
        daily_size = [(visit_pool.size * share).round, 1].max
        visit_pool
          .sample(daily_size, random: @rng)
          .each do |user|
            next if user.created_at.to_date > date
            begin
              UserVisit.find_or_create_by!(user_id: user.id, visited_at: date) do |v|
                v.mobile = @rng.rand < 0.4
                v.posts_read = @rng.rand(0..30)
                v.time_read = @rng.rand(60..1200)
              end
            rescue ActiveRecord::RecordNotUnique
            end
          end
      end
      UserVisit.ensure_consistency!

      DB.exec(<<~SQL)
        UPDATE user_stats
        SET days_visited = (SELECT COUNT(*) FROM user_visits WHERE user_visits.user_id = user_stats.user_id)
      SQL
      log "user_visits seeded"
    end

    # --------------------------------------------------------------------------
    # APPLICATION REQUESTS  (Site Traffic chart)
    # --------------------------------------------------------------------------
    def seed_application_requests
      baseline = APPLICATION_REQUEST_BASELINE
      anon_mult = 5
      crawler_mult = 8
      embed_mult = 0.05
      legacy_overhead = 3
      jitter = 0.30

      req_types = ::ApplicationRequest.req_types
      ar_rows = []
      total_days = [(@end_date - @start_date).to_i, 1].max

      (@start_date..@end_date).each do |date|
        drift = 0.5 + ((1.0 - 0.5) * (date - @start_date).to_i / total_days)
        base = baseline * drift * day_factor(date)
        base *= (1.0 - jitter / 2) + (@rng.rand * jitter)

        lib = [base.round, 1].max
        ar_rows << [date, req_types[:page_view_logged_in_browser], lib]
        ar_rows << [date, req_types[:page_view_anon_browser], (lib * anon_mult).round]
        ar_rows << [date, req_types[:page_view_crawler], (lib * crawler_mult).round]
        ar_rows << [date, req_types[:page_view_embed], (lib * embed_mult).round]
        ar_rows << [date, req_types[:page_view_logged_in], (lib * legacy_overhead).round]
        ar_rows << [date, req_types[:page_view_anon], (lib * anon_mult * legacy_overhead).round]
      end

      values_sql = ar_rows.map { |d, t, c| "('#{d}', #{t}, #{c})" }.join(",")
      DB.exec(<<~SQL)
        INSERT INTO application_requests (date, req_type, count)
        VALUES #{values_sql}
        ON CONFLICT (date, req_type) DO UPDATE SET count = EXCLUDED.count
      SQL
      log "application_requests upserted (#{ar_rows.size} rows)"
    end

    # --------------------------------------------------------------------------
    # BROWSER PAGEVIEW ROLLUPS  (Traffic cards + session KPIs)
    # --------------------------------------------------------------------------
    def seed_browser_pageview_rollups
      SiteSetting.persist_browser_pageview_events = true

      country_rows = []
      referrer_rows = []
      session_rows = []

      (@start_date..@end_date).each do |date|
        human_pageviews = human_browser_pageviews(date)
        next if human_pageviews.zero?

        COUNTRY_TRAFFIC_SHARES.each do |country_code, share|
          count = (human_pageviews * share * daily_jitter).round
          logged_in_count = (count * (0.16 + @rng.rand * 0.05)).round
          country_rows << [date, country_code, count, logged_in_count]
        end

        REFERRER_TRAFFIC_SHARES.each do |referrer, share|
          count = (human_pageviews * share * daily_jitter).round
          logged_in_count = (count * (0.14 + @rng.rand * 0.06)).round
          referrer_rows << [date, referrer, count, logged_in_count]
        end

        total_sessions = [(human_pageviews / (3.0 + @rng.rand * 2.0)).round, 1].max
        logged_in_sessions = (total_sessions * (0.18 + @rng.rand * 0.05)).round
        anonymous_sessions = total_sessions - logged_in_sessions

        [[false, anonymous_sessions], [true, logged_in_sessions]].each do |logged_in, sessions|
          next if sessions.zero?

          bounce_rate = logged_in ? 0.21 + @rng.rand * 0.09 : 0.34 + @rng.rand * 0.12
          avg_seconds = logged_in ? @rng.rand(210..480) : @rng.rand(55..170)
          session_rows << [
            date,
            logged_in,
            sessions,
            (sessions * bounce_rate).round,
            sessions * avg_seconds,
          ]
        end
      end

      upsert_country_rollups(country_rows)
      upsert_referrer_rollups(referrer_rows)
      upsert_session_rollups(session_rows)

      log "browser pageview rollups upserted (countries=#{country_rows.size}, referrers=#{referrer_rows.size}, sessions=#{session_rows.size})"
    end

    def upsert_country_rollups(rows)
      return if rows.empty?

      values_sql =
        rows
          .map do |date, country_code, count, logged_in_count|
            "(#{quote(date)}, #{quote(country_code)}, #{count}, #{logged_in_count})"
          end
          .join(",")

      DB.exec(<<~SQL)
        INSERT INTO browser_pageview_country_daily_rollups
          (date, country_code, count, logged_in_count)
        VALUES #{values_sql}
        ON CONFLICT (date, country_code) DO UPDATE
          SET count = EXCLUDED.count,
              logged_in_count = EXCLUDED.logged_in_count
      SQL
    end

    def upsert_referrer_rollups(rows)
      return if rows.empty?

      values_sql =
        rows
          .map do |date, referrer, count, logged_in_count|
            "(#{quote(date)}, #{quote(referrer)}, #{count}, #{logged_in_count})"
          end
          .join(",")

      DB.exec(<<~SQL)
        INSERT INTO browser_pageview_referrer_daily_rollups
          (date, normalized_referrer, count, logged_in_count)
        VALUES #{values_sql}
        ON CONFLICT (date, normalized_referrer) DO UPDATE
          SET count = EXCLUDED.count,
              logged_in_count = EXCLUDED.logged_in_count
      SQL
    end

    def upsert_session_rollups(rows)
      return if rows.empty?

      values_sql =
        rows
          .map do |date, logged_in, sessions, bounced, engaged_seconds_total|
            "(#{quote(date)}, #{logged_in}, #{sessions}, #{bounced}, #{engaged_seconds_total})"
          end
          .join(",")

      DB.exec(<<~SQL)
        INSERT INTO browser_pageview_session_engagement_daily_rollups
          (date, logged_in, sessions, bounced, engaged_seconds_total)
        VALUES #{values_sql}
        ON CONFLICT (date, logged_in) DO UPDATE
          SET sessions = EXCLUDED.sessions,
              bounced = EXCLUDED.bounced,
              engaged_seconds_total = EXCLUDED.engaged_seconds_total
      SQL
    end

    # --------------------------------------------------------------------------
    # SEARCH LOGS  (Search section)
    # --------------------------------------------------------------------------
    def seed_search_logs
      SiteSetting.log_search_queries = true

      user_ids = User.real.where(active: true).where.not(username: PROTECTED_USERNAMES).pluck(:id)
      return log("search logs skipped: no real active users") if user_ids.empty?

      seed_start_date = @start_date - 90.days
      SearchLog
        .where(user_agent: SEARCH_SEED_USER_AGENT)
        .where(created_at: seed_start_date.beginning_of_day..@end_date.end_of_day)
        .delete_all

      rows = []
      (seed_start_date..@end_date).each do |date|
        SEARCH_TERM_PROFILES.each do |profile|
          daily_count =
            (@rng.rand(profile[:min]..profile[:max]) * day_factor(date) * search_drift(date)).round
          next if daily_count.zero?

          daily_count.times do
            clicked = @rng.rand < profile[:click_rate]
            rows << {
              term: profile[:term],
              user_id: user_ids.sample(random: @rng),
              ip_address: "127.0.0.1",
              search_type: SearchLog.search_types[:header],
              search_result_id: clicked ? @rng.rand(1..50_000) : nil,
              search_result_type: clicked ? SearchLog.search_result_types[:topic] : nil,
              user_agent: SEARCH_SEED_USER_AGENT,
              created_at: date.to_time + @rng.rand(0..86_399).seconds,
            }
          end
        end
      end

      rows.each_slice(5_000) { |slice| SearchLog.insert_all(slice) } if rows.any?
      log "search_logs seeded: #{rows.size}"
    end

    # --------------------------------------------------------------------------
    # TRUST LEVEL PIPELINE MOVEMENT
    # --------------------------------------------------------------------------
    def seed_trust_level_pipeline_changes
      action_ids = [
        UserHistory.actions[:change_trust_level],
        UserHistory.actions[:auto_trust_level_change],
      ]
      users =
        User
          .real
          .where(active: true)
          .where.not(username: PROTECTED_USERNAMES)
          .order(:id)
          .limit(TRUST_LEVEL_CHANGE_TARGET)
          .to_a
      return log("trust level changes skipped: no users") if users.empty?

      UserHistory
        .where(action: action_ids, target_user_id: users.map(&:id), details: SEARCH_SEED_USER_AGENT)
        .where(created_at: @start_date.beginning_of_day..@end_date.end_of_day)
        .delete_all

      rows = []
      users.each_with_index do |user, index|
        previous_tl =
          case index % 12
          when 0, 1, 2, 3, 4
            0
          when 5, 6, 7, 8
            1
          when 9, 10
            2
          else
            3
          end
        new_tl =
          case previous_tl
          when 0
            1
          when 1
            index.even? ? 2 : 0
          when 2
            index.even? ? 3 : 1
          else
            2
          end
        at = @start_date.to_time + @rng.rand(0..WINDOW_DAYS.days.to_i).seconds
        at = Time.now if at > Time.now

        rows << {
          action: UserHistory.actions[:auto_trust_level_change],
          target_user_id: user.id,
          previous_value: previous_tl.to_s,
          new_value: new_tl.to_s,
          details: SEARCH_SEED_USER_AGENT,
          created_at: at,
          updated_at: at,
        }
        user.update_columns(trust_level: new_tl)
      end

      UserHistory.insert_all(rows) if rows.any?
      log "trust level changes seeded: #{rows.size}"
    end

    # --------------------------------------------------------------------------
    # TOPIC VIEW STATS  (Activity by category -> Page Views)
    # That column reads topic_view_stats (anon + logged-in views per topic per
    # day), NOT application_requests. seed per topic with a post-creation decay so
    # views cluster after a topic appears, scaled by day_factor for spike days.
    # --------------------------------------------------------------------------
    def seed_topic_view_stats
      TopicViewStat.delete_all
      view_rows = []
      Topic
        .where(archetype: "regular")
        .pluck(:id, :created_at)
        .each do |tid, created|
          first_day = [created.to_date, @start_date].max
          (first_day..@end_date).each do |date|
            decay = 1.0 / (1 + (date - first_day).to_i)
            base = @rng.rand * VIEWS_PER_TOPIC_DAY * decay * day_factor(date)
            anon = base.round
            logged_in = (base * 0.3 * @rng.rand).round
            next if anon.zero? && logged_in.zero?
            view_rows << {
              topic_id: tid,
              viewed_at: date,
              anonymous_views: anon,
              logged_in_views: logged_in,
            }
          end
        end
      view_rows.each_slice(10_000) { |slice| TopicViewStat.insert_all(slice) } if view_rows.any?
      log "topic_view_stats seeded (#{view_rows.size} rows)"
    end

    # --------------------------------------------------------------------------
    # LIKES  (drives the Likes report + Daily Engaged Users)
    # Seed post_actions + both user_actions rows directly with the right
    # created_at, then reconcile counters — skipping the full PostActionCreator
    # path (notifications, badges, jobs) which is slow and leaves the user_actions
    # rows the Daily Engaged Users report reads stamped at "now".
    # --------------------------------------------------------------------------
    def seed_likes
      like_type = PostActionType.types[:like]
      like_pool = User.where("id > 0").where(active: true).pluck(:id)

      like_rows = []
      ua_rows = []
      Post
        .where("user_id > 0")
        .select(:id, :user_id, :topic_id, :created_at)
        .find_each do |post|
          next if @rng.rand > LIKE_PROBABILITY
          (like_pool - [post.user_id])
            .sample(@rng.rand(1..3), random: @rng)
            .each do |liker_id|
              like_at = post.created_at + @rng.rand(1..48).hours
              like_at = Time.now if like_at > Time.now
              like_rows << {
                post_id: post.id,
                user_id: liker_id,
                post_action_type_id: like_type,
                created_at: like_at,
                updated_at: like_at,
              }
              ua_rows << {
                action_type: UserAction::LIKE,
                user_id: liker_id,
                acting_user_id: liker_id,
                target_post_id: post.id,
                target_topic_id: post.topic_id,
                created_at: like_at,
                updated_at: like_at,
              }
              ua_rows << {
                action_type: UserAction::WAS_LIKED,
                user_id: post.user_id,
                acting_user_id: liker_id,
                target_post_id: post.id,
                target_topic_id: post.topic_id,
                created_at: like_at,
                updated_at: like_at,
              }
            end
        end

      # wipe seeded likes so re-runs don't accumulate, then bulk insert
      DB.exec("DELETE FROM post_actions WHERE post_action_type_id = #{like_type} AND user_id > 0")
      DB.exec(
        "DELETE FROM user_actions WHERE action_type IN (#{UserAction::LIKE}, #{UserAction::WAS_LIKED}) AND user_id > 0",
      )
      like_rows.each_slice(5_000) { |slice| PostAction.insert_all(slice) } if like_rows.any?
      ua_rows.each_slice(5_000) { |slice| UserAction.insert_all(slice) } if ua_rows.any?

      # reconcile denormalized counters in bulk (reset first, since the liked set
      # may differ from whatever older runs wrote)
      DB.exec("UPDATE posts SET like_count = 0 WHERE like_count <> 0")
      DB.exec("UPDATE topics SET like_count = 0 WHERE like_count <> 0")
      DB.exec(
        "UPDATE user_stats SET likes_given = 0, likes_received = 0 WHERE likes_given <> 0 OR likes_received <> 0",
      )
      DB.exec(<<~SQL)
        UPDATE posts SET like_count = c.cnt
        FROM (
          SELECT post_id, COUNT(*) AS cnt FROM post_actions
          WHERE post_action_type_id = #{like_type} AND deleted_at IS NULL GROUP BY post_id
        ) c
        WHERE posts.id = c.post_id
      SQL
      DB.exec(<<~SQL)
        UPDATE topics SET like_count = c.cnt
        FROM (SELECT topic_id, SUM(like_count) AS cnt FROM posts GROUP BY topic_id) c
        WHERE topics.id = c.topic_id AND c.cnt > 0
      SQL
      DB.exec(<<~SQL)
        UPDATE user_stats SET likes_given = g.cnt
        FROM (
          SELECT user_id, COUNT(*) AS cnt FROM post_actions
          WHERE post_action_type_id = #{like_type} AND deleted_at IS NULL GROUP BY user_id
        ) g
        WHERE user_stats.user_id = g.user_id
      SQL
      DB.exec(<<~SQL)
        UPDATE user_stats SET likes_received = r.cnt
        FROM (
          SELECT p.user_id, COUNT(*) AS cnt
          FROM post_actions pa JOIN posts p ON p.id = pa.post_id
          WHERE pa.post_action_type_id = #{like_type} AND pa.deleted_at IS NULL GROUP BY p.user_id
        ) r
        WHERE user_stats.user_id = r.user_id
      SQL
      log "likes seeded: #{like_rows.size}"
    end

    # --------------------------------------------------------------------------
    # ACCEPTED SOLUTIONS  (if discourse-solved is installed)
    # --------------------------------------------------------------------------
    def seed_accepted_solutions
      return unless defined?(DiscourseSolved::SolvedTopic)
      SiteSetting.allow_solved_on_all_topics = true

      # discourse-solved split into two tables (migration 20260408165014):
      #   discourse_solved_solved_topics  -> topic_id + created_at (the report groups by this)
      #   discourse_solved_topic_answers  -> answer_post_id + accepter_user_id
      # SolvedTopic now lists answer_post_id/accepter_user_id in ignored_columns, so the old
      # `SolvedTopic.create!(answer_post_id:, accepter_user_id:)` silently drops the answer and
      # never lands a counted solution. write both tables via raw SQL so this stays correct
      # whether the legacy columns are still present and whether triggers are active.
      solved_columns =
        DB.query_single(
          "SELECT column_name FROM information_schema.columns " \
            "WHERE table_name = 'discourse_solved_solved_topics'",
        )
      has_legacy_answer_cols = solved_columns.include?("answer_post_id")
      has_topic_answers =
        DB.query_single(
          "SELECT 1 FROM information_schema.tables " \
            "WHERE table_name = 'discourse_solved_topic_answers'",
        ).present?

      mark_solved =
        lambda do |topic_id:, post_id:, accepter_id:, at:|
          solved_id =
            if has_legacy_answer_cols
              DB.query_single(<<~SQL, topic_id:, post_id:, accepter_id:, at:).first
                INSERT INTO discourse_solved_solved_topics
                  (topic_id, answer_post_id, accepter_user_id, created_at, updated_at)
                VALUES (:topic_id, :post_id, :accepter_id, :at, :at)
                ON CONFLICT (topic_id) DO UPDATE
                  SET answer_post_id = EXCLUDED.answer_post_id,
                      accepter_user_id = EXCLUDED.accepter_user_id,
                      created_at = EXCLUDED.created_at,
                      updated_at = EXCLUDED.updated_at
                RETURNING id
              SQL
            else
              DB.query_single(<<~SQL, topic_id:, at:).first
                INSERT INTO discourse_solved_solved_topics (topic_id, created_at, updated_at)
                VALUES (:topic_id, :at, :at)
                ON CONFLICT (topic_id) DO UPDATE
                  SET created_at = EXCLUDED.created_at, updated_at = EXCLUDED.updated_at
                RETURNING id
              SQL
            end

          DB.exec(<<~SQL, solved_id:, post_id:, accepter_id:, at:) if has_topic_answers && solved_id
              INSERT INTO discourse_solved_topic_answers
                (solved_topic_id, answer_post_id, accepter_user_id, created_at, updated_at)
              VALUES (:solved_id, :post_id, :accepter_id, :at, :at)
              ON CONFLICT (answer_post_id) DO UPDATE
                SET solved_topic_id = EXCLUDED.solved_topic_id,
                    accepter_user_id = EXCLUDED.accepter_user_id,
                    created_at = EXCLUDED.created_at,
                    updated_at = EXCLUDED.updated_at
            SQL
        end

      # new solutions for not-yet-solved topics
      candidates =
        Topic
          .where(archetype: Archetype.default)
          .where("posts_count > 1")
          .where.not(id: DiscourseSolved::SolvedTopic.select(:topic_id))
          .to_a
      candidates
        .shuffle(random: @rng)
        .each do |topic|
          reply = topic.posts.where("post_number > 1").order("RANDOM()").first
          next unless reply
          # weight by day_factor so spike days land many solutions and quiet days
          # few — gives the report real variation instead of a flat 0-4/day.
          next if @rng.rand > SOLUTION_SHARE * day_factor(reply.created_at.to_date)
          solved_at = reply.created_at + @rng.rand(1..6).hours
          solved_at = Time.now if solved_at > Time.now
          mark_solved.call(
            topic_id: topic.id,
            post_id: reply.id,
            accepter_id: topic.user_id,
            at: solved_at,
          )
        rescue => e
          log "solve skip: #{e.message.lines.first}"
        end

      # re-stamp existing solutions so they roll forward with the (rewritten) post
      # dates every run, instead of freezing at the date they were first solved.
      if has_topic_answers
        DiscourseSolved::TopicAnswer.find_each do |ta|
          post = Post.find_by(id: ta.answer_post_id)
          next unless post
          at = post.created_at + @rng.rand(1..6).hours
          at = Time.now if at > Time.now
          mark_solved.call(
            topic_id: post.topic_id,
            post_id: ta.answer_post_id,
            accepter_id: ta.accepter_user_id,
            at:,
          )
        end
      end

      log "solutions in window: #{DiscourseSolved::SolvedTopic.where(created_at: @start_date..@end_date).count}"
    end

    # --------------------------------------------------------------------------
    # SUPPORT SECTION  (in-progress outcomes + who's answering)
    # --------------------------------------------------------------------------
    def seed_support_section_metrics
      return unless defined?(DiscourseSolved::SolvedTopic)

      SiteSetting.solved_enabled = true
      SiteSetting.allow_solved_on_all_topics = true

      category_ids = Category.where(read_restricted: false).where("id > 1").pluck(:id)
      return log("support metrics skipped: no public categories") if category_ids.empty?

      topics =
        Topic
          .where(archetype: Archetype.default, category_id: category_ids)
          .where("created_at >= ?", 90.days.ago)
          .where(deleted_at: nil)
          .order("RANDOM()")
          .limit(SUPPORT_TOPIC_TARGET)
          .to_a
      return log("support metrics skipped: no recent topics") if topics.empty?

      pools = support_answerer_pools
      return log("support metrics skipped: no answerer pool") if pools.values.flatten.empty?

      in_progress_topics = topics.first([topics.size / 3, 500].max)
      remove_solutions_for_topics(in_progress_topics.map(&:id))

      buckets = %i[staff member regular leader basic]
      replies = 0
      topics.each_with_index do |topic, index|
        bucket = buckets[index % buckets.size]
        answerer = (pools[bucket].presence || pools.values.flatten).sample(random: @rng)
        next unless answerer && answerer.id != topic.user_id

        replies += ensure_support_replies(topic, answerer, 2 + (index % 4))
      rescue => e
        log "support reply skip topic #{topic.id}: #{e.message.lines.first}"
      end

      log "support metrics seeded: in_progress=#{in_progress_topics.size}, replies=#{replies}"
    end

    def support_answerer_pools
      staff = User.where("admin OR moderator").where("id > 0").to_a
      real_users =
        User
          .real
          .where(active: true)
          .where.not(username: PROTECTED_USERNAMES)
          .order(:id)
          .limit(100)
          .to_a

      buckets = { staff: staff }
      { leader: 4, regular: 3, member: 2, basic: 1 }.each_with_index do |(bucket, trust_level), i|
        assigned = real_users.drop(i * 10).first(10)
        User.where(id: assigned.map(&:id)).update_all(trust_level: trust_level) if assigned.any?
        buckets[bucket] = assigned
      end

      buckets
    end

    def ensure_support_replies(topic, answerer, target_count)
      reply_at = topic.created_at + @rng.rand(30.minutes.to_i..36.hours.to_i).seconds
      reply_at = Time.now if reply_at > Time.now
      replies =
        Post
          .where(topic_id: topic.id, post_type: Post.types[:regular], deleted_at: nil)
          .where("post_number > 1")
          .order(:created_at)
          .limit(target_count)
          .to_a

      replies.each do |reply|
        reply.update_columns(user_id: answerer.id, created_at: reply_at, updated_at: reply_at)
        reply_at += @rng.rand(15.minutes.to_i..4.hours.to_i).seconds
        reply_at = Time.now if reply_at > Time.now
      end

      while replies.size < target_count
        reply =
          PostCreator.create!(
            answerer,
            raw:
              "Thanks, this should help narrow support topic #{topic.id}. " \
                "Seed reply #{SecureRandom.hex(8)}.",
            topic_id: topic.id,
            skip_jobs: true,
            skip_validations: true,
          )
        reply.update_columns(created_at: reply_at, updated_at: reply_at)
        replies << reply
        reply_at += @rng.rand(15.minutes.to_i..4.hours.to_i).seconds
        reply_at = Time.now if reply_at > Time.now
      end

      last_reply = replies.max_by(&:created_at)
      topic.update_columns(
        last_post_user_id: answerer.id,
        last_posted_at: last_reply.created_at,
        bumped_at: last_reply.created_at,
      )
      replies.size
    end

    def remove_solutions_for_topics(topic_ids)
      return if topic_ids.empty?

      DB.exec(<<~SQL, topic_ids: topic_ids) if defined?(DiscourseSolved::TopicAnswer)
          DELETE FROM discourse_solved_topic_answers
          WHERE solved_topic_id IN (
            SELECT id FROM discourse_solved_solved_topics WHERE topic_id IN (:topic_ids)
          )
        SQL

      DB.exec(<<~SQL, topic_ids: topic_ids)
        DELETE FROM discourse_solved_solved_topics
        WHERE topic_id IN (:topic_ids)
      SQL
    end

    def log_summary
      log "=" * 60
      log "Last 90 days:"
      log "  Sign-ups:     #{User.where("created_at >= ?", 90.days.ago).count}"
      log "  Contributors: #{User.count_by_first_post(90.days.ago, Date.today).values.sum}"
      log "  Topics:       #{Topic.where("created_at >= ?", 90.days.ago).count}"
      log "  Posts:        #{Post.where("created_at >= ?", 90.days.ago).count}"
      log "  Visits:       #{UserVisit.where("visited_at >= ?", 90.days.ago.to_date).count}"
      log "  Pageviews:    #{ApplicationRequest.where("date >= ?", 90.days.ago.to_date).sum(:count)}"
      log "  Likes:        #{PostAction.where(post_action_type_id: PostActionType.types[:like]).where("created_at >= ?", 90.days.ago).count}"
      if defined?(DiscourseSolved::SolvedTopic)
        log "  Solutions:    #{DiscourseSolved::SolvedTopic.where("created_at >= ?", 90.days.ago).count}"
      end
      log "  Search logs:  #{SearchLog.where(user_agent: SEARCH_SEED_USER_AGENT).where("created_at >= ?", 90.days.ago).count}"
      log "upkeep done in #{(Time.now - @started_at).to_i}s"
    end

    def clear_dashboard_cache
      Report.clear_cache
      Discourse.redis.del(
        *[AdminDashboardData, AdminDashboardIndexData, AdminDashboardGeneralData].map(
          &:stats_cache_key
        ),
      )
      log "dashboard cache cleared"
    end

    # ------------------------------------------------------------------------
    # helpers
    # ------------------------------------------------------------------------
    def us_thanksgiving(year)
      d = Date.new(year, 11, 1)
      d += (4 - d.wday) % 7
      d + 21
    end

    # day_factor: weekends ×0.7, holidays ×0.3, spikes ×2–4, mega-spike ×5–9
    def day_factor(date)
      return 5.0 + @rng.rand * 4.0 if date == @mega_spike_date
      return 2.0 + @rng.rand * 2.0 if @spike_dates.include?(date)
      f = 1.0
      f *= 0.7 if date.saturday? || date.sunday?
      f *= 0.3 if @holidays.include?(date) || FIXED_HOLIDAYS_MD.include?([date.month, date.day])
      f
    end

    def human_browser_pageviews(date)
      req_types = ::ApplicationRequest.req_types
      ::ApplicationRequest.where(
        date: date,
        req_type: [req_types[:page_view_logged_in_browser], req_types[:page_view_anon_browser]],
      ).sum(:count)
    end

    def daily_jitter
      0.88 + @rng.rand * 0.24
    end

    def search_drift(date)
      total_days = [(@end_date - (@start_date - 90.days)).to_i, 1].max
      0.65 + ((1.0 - 0.65) * (date - (@start_date - 90.days)).to_i / total_days)
    end

    def quote(value)
      ActiveRecord::Base.connection.quote(value)
    end

    # 60% inside the 3-month dashboard window, 40% spread back across ~5 years
    def biased_random_time
      if @rng.rand < RECENT_SHARE
        Time.now - @rng.rand(0..@recent_window_days).days - @rng.rand(0..86_399).seconds
      else
        Time.now - (@recent_window_days + 1 + @rng.rand(0..1735)).days -
          @rng.rand(0..86_399).seconds
      end
    end

    def log(msg)
      Rails.logger.info("[dashboard_upkeep] [#{(Time.now - @started_at).to_i}s] #{msg}")
    end
  end
end
