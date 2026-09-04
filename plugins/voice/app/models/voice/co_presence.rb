# frozen_string_literal: true

module Voice
  class CoPresence < ActiveRecord::Base
    self.table_name = "#{Voice.table_name_prefix}co_presences"

    belongs_to :user_1, class_name: "User"
    belongs_to :user_2, class_name: "User"

    validates :user_id_1, comparison: { less_than: :user_id_2 }

    class << self
      def top_contacts_for(user_id, since:, limit: 10)
        uid = user_id.to_i
        where("(user_id_1 = :uid OR user_id_2 = :uid) AND date >= :since", uid: uid, since: since)
          .select(
            Arel.sql(
              "CASE WHEN user_id_1 = #{uid} THEN user_id_2 ELSE user_id_1 END AS contact_id",
            ),
            Arel.sql("SUM(total_seconds) AS total_seconds"),
            Arel.sql("SUM(session_count) AS session_count"),
            Arel.sql("MAX(date) AS last_co_present_on"),
          )
          .group(Arel.sql("contact_id"))
          .order(Arel.sql("total_seconds DESC"))
          .limit(limit)
      end
    end
  end
end

# == Schema Information
#
# Table name: voice_co_presences
#
#  id            :bigint           not null, primary key
#  date          :date             not null
#  session_count :integer          default(0), not null
#  total_seconds :integer          default(0), not null
#  user_id_1     :integer          not null
#  user_id_2     :integer          not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  idx_voice_co_presences_unique                   (user_id_1,user_id_2,date) UNIQUE
#  index_voice_co_presences_on_user_id_1_and_date  (user_id_1,date)
#  index_voice_co_presences_on_user_id_2_and_date  (user_id_2,date)
#
