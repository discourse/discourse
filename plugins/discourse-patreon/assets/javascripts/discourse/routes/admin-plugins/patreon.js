import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Group from "discourse/models/group";
import DiscourseRoute from "discourse/routes/discourse";
import FilterRule from "discourse/plugins/discourse-patreon/discourse/models/filter-rule";

/* We use three main model to get this page working:
 *  Discourse Groups (excluding the automatic ones), Patreon rewards and
 *  and current filters (one filter is a tuple between 1 Discourse group and N Patreon rewards)
 */
export default class AdminPluginsPatreon extends DiscourseRoute {
  model() {
    return Promise.all([
      ajax("/patreon/list.json"),
      Group.findAll({ ignore_automatic: true }),
    ])
      .then(([result, groups]) => {
        groups = groups.map((g) => {
          return { id: g.id, name: g.name };
        });

        return {
          filters: result.filters,
          rewards: result.rewards,
          last_sync_at: result.last_sync_at,
          groups,
        };
      })
      .catch(popupAjaxError);
  }

  setupController(controller, model) {
    const rewards = model.rewards;
    const groups = model.groups;
    const filtersArray = Object.entries(model.filters).map(([k, v]) => {
      const rewardsNames = v.map((r) =>
        rewards[r]
          ? ` $${rewards[r].amount_cents / 100} - ${rewards[r].title}`
          : ""
      );
      const group = groups.find((g) => g.id === parseInt(k, 10));

      return FilterRule.create({
        group: group.name,
        rewards: rewardsNames,
        group_id: k,
        reward_ids: v,
      });
    });

    controller.setProperties({
      model: filtersArray,
      groups,
      rewards,
      last_sync_at: model.last_sync_at,
    });
  }
}
