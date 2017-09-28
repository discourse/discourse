class CorrectPostActionIndex < ActiveRecord::Migration[4.2]

  def up

    # NOTE: not stored in the table yet, is_flag contains notify_user
    #  hardcoding, long term we can store all metadata and join for index
    # This means that if we muck with flag types we need to redo this index
    #  flag types have been stable for a while so we should be ok
    #
    # Another solution is hoisting an extra boolean into the post action table
    #
    # {:off_topic=>3, :inappropriate=>4, :notify_moderators=>7, :spam=>8}
    flag_ids = "3,4,7,8"

   x = execute "DELETE FROM post_actions pa
                    USING post_actions pa2
             WHERE pa.post_action_type_id IN (#{flag_ids}) AND
                   pa2.post_action_type_id IN (#{flag_ids}) AND
                   pa.deleted_at IS NULL AND
                   pa2.deleted_at IS NULL AND
                   pa.disagreed_at IS NULL AND
                   pa2.disagreed_at IS NULL AND
                   pa.deferred_at IS NULL AND
                   pa2.deferred_at IS NULL AND
                   pa.id < pa2.id AND
                   pa.user_id = pa2.user_id AND
                   pa.post_id = pa2.post_id AND
                   pa.targets_topic = pa2.targets_topic"

    puts
    puts ">> DELETED #{x.cmd_tuples} invalid rows from post_actions"
    puts

    add_index :post_actions,
                ["user_id", "post_id", "targets_topic"],
                name: "idx_unique_flags",
                unique: true,
                where: "deleted_at IS NULL AND
                        disagreed_at IS NULL AND
                        deferred_at IS NULL AND
                        post_action_type_id IN (#{flag_ids})"
  end

  def down
    remove_index "post_actions", name: "idx_unique_flags"
  end
end
