Group.ensure_automatic_groups!
if g = Group.find_by(name: 'trust_level_5', id: 15)
  g.destroy!
end

Group.where(name: 'everyone').update_all(visibility_level: Group.visibility_levels[:owners])

ColumnDropper.drop(
  table: 'groups',
  after_migration: 'AddVisibleBackToGroups',
  columns:  %w[visible],
  on_drop: ->(){
    STDERR.puts 'Removing superflous visible group column!'
  }
)
