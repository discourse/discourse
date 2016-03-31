class FixIncorrectUserHistory < ActiveRecord::Migration
  def up
    # see https://meta.discourse.org/t/old-user-suspension-reasons-have-gone-missing/3730
    # we had a window of 21 days where all user history records with action > 5 were off by one
    #
    # to correct we are doing this https://meta.discourse.org/t/enums-that-are-used-in-tables-need-to-be-stable/37622
    #
    # This migration hunts for date stuff started going wrong and date it started being good and corrects the data


    # this is a :auto_trust_level_change mislabled as :check_email
    # impersonate that was actually delete topic
    condition = <<CLAUSE
(action = 16 AND previous_value in ('0','1','2','3','4')) OR
(action = 19 AND target_user_id IS NULL AND details IS NOT NULL)
CLAUSE

    first_wrong_id = execute("SELECT min(id) FROM user_histories WHERE #{condition}").values[0][0].to_i
    last_wrong_id = execute("SELECT max(id) FROM user_histories WHERE #{condition}").values[0][0].to_i

    if first_wrong_id < last_wrong_id
      msg = "Correcting user history records from id: #{first_wrong_id} to #{last_wrong_id} (see: https://meta.discourse.org/t/old-user-suspension-reasons-have-gone-missing/3730)"

      execute("UPDATE user_histories SET action = action - 1
               WHERE action > 5 AND id >= #{first_wrong_id} AND id <= #{last_wrong_id}")

      execute("INSERT INTO user_histories(action, acting_user_id, details, created_at, updated_at)
               VALUES (22, -1, '#{msg}', current_timestamp, current_timestamp)")
    end
  end

  def down
  end
end
