# frozen_string_literal: true

class MakePostNumberDistinct < ActiveRecord::Migration[4.2]
  def up

    DB.exec('update posts p
set post_number = calc
from
(
	select
		id,
		post_number,
		topic_id,
		row_number() over (partition by topic_id order by post_number, created_at) calc
	from posts
	where topic_id in (
	select topic_id from posts
	  group by topic_id, post_number
	  having count(*)>1
	)

) as X
where calc <> p.post_number and X.id = p.id')
  end

  def down
    # don't want to mess with the index ... its annoying
    raise ActiveRecord::IrreversibleMigration
  end
end
