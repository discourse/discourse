class DenormalizeExpressions < ActiveRecord::Migration
  def change

    # Denormalizing this makes our queries so, so, so much nicer

    add_column :posts, :expression1_count, :integer, null: false, default: 0
    add_column :posts, :expression2_count, :integer, null: false, default: 0
    add_column :posts, :expression3_count, :integer, null: false, default: 0
    add_column :posts, :expression4_count, :integer, null: false, default: 0
    add_column :posts, :expression5_count, :integer, null: false, default: 0

    add_column :forum_threads, :expression1_count, :integer, null: false, default: 0
    add_column :forum_threads, :expression2_count, :integer, null: false, default: 0
    add_column :forum_threads, :expression3_count, :integer, null: false, default: 0
    add_column :forum_threads, :expression4_count, :integer, null: false, default: 0
    add_column :forum_threads, :expression5_count, :integer, null: false, default: 0


    (1..5).each do |i|
      execute "update posts set expression#{i}_count = (select count(*) from expressions where parent_id = posts.id and expression_type_id = #{i})"
      execute "update forum_threads set expression#{i}_count = (select sum(expression#{i}_count) from posts where forum_thread_id = forum_threads.id)"
    end
  end

end
