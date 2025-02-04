import Controller from "@ember/controller";
import discourseComputed from "discourse/lib/decorators";

function badgeKey(badge) {
  let pos = badge.get("badge_grouping.position");
  let type = badge.get("badge_type_id");
  let name = badge.get("name");
  return ("000" + pos).slice(-4) + (10 - type) + name;
}

export default class IndexController extends Controller {
  @discourseComputed("model")
  badgeGroups(model) {
    let sorted = model.sort((a, b) => badgeKey(a).localeCompare(badgeKey(b)));
    let grouped = [];
    let group = [];
    let groupId;

    sorted.forEach(function (badge) {
      if (groupId !== badge.badge_grouping_id) {
        if (group && group.length > 0) {
          grouped.push({
            badges: group,
            badgeGrouping: group[0].badge_grouping,
          });
        }
        group = [];
        groupId = badge.badge_grouping_id;
      }
      group.push(badge);
    });

    if (group && group.length > 0) {
      grouped.push({ badges: group, badgeGrouping: group[0].badge_grouping });
    }

    return grouped;
  }
}
