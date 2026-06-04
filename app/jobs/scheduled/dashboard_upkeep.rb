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
    PROTECTED_USERNAMES = %w[system discobot tomtom steak].freeze
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
      seed_topic_view_stats
      seed_likes
      seed_accepted_solutions
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
      baseline = 5_000
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
