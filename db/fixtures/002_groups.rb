# frozen_string_literal: true

Group.ensure_automatic_groups!
if g = Group.find_by(name: "trust_level_5", id: 15)
  g.destroy!
end

Group.where(
  id: [
    Group::AUTO_GROUPS[:everyone],
    Group::AUTO_GROUPS[:anonymous_users],
    Group::AUTO_GROUPS[:logged_in_users],
  ],
).update_all(visibility_level: Group.visibility_levels[:logged_on_users])
