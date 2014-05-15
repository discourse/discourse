class RetireExpressions < ActiveRecord::Migration
  def up
    execute 'insert into post_actions (post_action_type_id, user_id, post_id, created_at, updated_at)
select
	case
	  when expression_index=1 then 3
	  when expression_index=2 then 4
	  when expression_index=3 then 2
	end

	, user_id, post_id, created_at, updated_at from expressions'

    drop_table 'expressions'
    drop_table 'expression_types'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
