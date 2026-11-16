# frozen_string_literal: true

module DiscourseRewind
  module Action
    class LiveUsage < BaseReport
      MINIMUM_SECONDS = 1.hour.to_i
      TOP_LIMIT = 3

      # A session with no end is either live or was never swept; either way
      # its real length is unknown, so it counts as a short call.
      UNENDED_SESSION_CAP = "30 minutes"

      FakeData = {
        data: {
          total_seconds: 310_440,
          call_count: 214,
          top_rooms: [
            { room_id: 1, name: "Game night", slug: "game-night", seconds: 147_600 },
            { room_id: 2, name: "Coworking", slug: "coworking", seconds: 82_800 },
            { room_id: 3, name: "Town hall", slug: "town-hall", seconds: 21_600 },
          ],
          top_contacts: [
            {
              user: {
                id: 2,
                username: "sam",
                name: "Sam",
                avatar_template: "/letter_avatar_proxy/v4/letter/s/8c91d9/{size}.png",
              },
              seconds: 133_200,
            },
            {
              user: {
                id: 3,
                username: "alex",
                name: "Alex",
                avatar_template: "/letter_avatar_proxy/v4/letter/a/e47774/{size}.png",
              },
              seconds: 64_800,
            },
            {
              user: {
                id: 4,
                username: "jo",
                name: "Jo",
                avatar_template: "/letter_avatar_proxy/v4/letter/j/3ab54a/{size}.png",
              },
              seconds: 25_200,
            },
          ],
        },
        identifier: "live-usage",
      }

      def call
        return FakeData if should_use_fake_data?

        sessions = Live::Session.where(user_id: user.id, joined_at: date)
        total_seconds, call_count =
          sessions.pick(Arel.sql("COALESCE(SUM(#{duration_sql}), 0)::bigint"), Arel.sql("COUNT(*)"))

        return if total_seconds < MINIMUM_SECONDS

        {
          data: {
            total_seconds:,
            call_count:,
            top_rooms: top_rooms(sessions),
            top_contacts:,
          },
          identifier: "live-usage",
        }
      end

      def self.filter_for_viewer(report, guardian:, for_user:)
        top_rooms = report[:data][:top_rooms]
        visible_room_ids = Live::Room.visible_to(guardian).where(id: top_rooms.pluck(:room_id)).ids

        report.deep_merge(
          data: {
            top_rooms: top_rooms.select { |room| room[:room_id].in?(visible_room_ids) },
            # Co-presence spans private rooms and calls, so who someone talks
            # to stays with them.
            top_contacts: guardian.is_me?(for_user) ? report[:data][:top_contacts] : [],
          },
        )
      end

      def self.enabled?
        plugin_enabled?("live")
      end

      private

      def duration_sql
        <<~SQL
          EXTRACT(EPOCH FROM (
            COALESCE(
              live_sessions.left_at,
              LEAST(CURRENT_TIMESTAMP, live_sessions.joined_at + INTERVAL '#{UNENDED_SESSION_CAP}')
            ) - live_sessions.joined_at
          ))
        SQL
      end

      def top_rooms(sessions)
        sessions
          .joins(:room)
          .merge(Live::Room.persistent)
          .group("live_rooms.id", "live_rooms.name", "live_rooms.slug")
          .order(Arel.sql("SUM(#{duration_sql}) DESC"), "live_rooms.id")
          .limit(TOP_LIMIT)
          .pluck(
            "live_rooms.id",
            "live_rooms.name",
            "live_rooms.slug",
            Arel.sql("SUM(#{duration_sql})::bigint"),
          )
          .map { |room_id, name, slug, seconds| { room_id:, name:, slug:, seconds: } }
      end

      def top_contacts
        # Over-fetch to leave headroom for contacts dropped below (bots, deleted users).
        contact_seconds =
          Live::CoPresence
            .where("user_id_1 = :id OR user_id_2 = :id", id: user.id)
            .where(date: date.first.to_date..date.last.to_date)
            .group(Arel.sql("CASE WHEN user_id_1 = #{user.id} THEN user_id_2 ELSE user_id_1 END"))
            .order(Arel.sql("SUM(total_seconds) DESC"))
            .limit(TOP_LIMIT * 3)
            .sum(:total_seconds)

        users = User.real.where(id: contact_seconds.keys).index_by(&:id)

        contact_seconds
          .filter_map do |contact_id, seconds|
            next if !(contact = users[contact_id])
            { user: BasicUserSerializer.new(contact, root: false).as_json, seconds: }
          end
          .first(TOP_LIMIT)
      end
    end
  end
end
