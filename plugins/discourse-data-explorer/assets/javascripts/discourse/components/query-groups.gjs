import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ShareReport from "./share-report.gjs";

export default class QueryGroups extends Component {
  @service warpStore;

  @tracked allGroups;

  constructor() {
    super(...arguments);

    // List responses cap each query's groups; `next` marks a truncated list.
    const links = this.args.query.hasMany("groups").links();
    if (links?.next) {
      this.#loadAll(links.related);
    }
  }

  get groups() {
    return this.allGroups ?? this.args.query.groups;
  }

  async #loadAll(related) {
    try {
      let { content: page } = await this.warpStore.request({ url: related });
      const groups = [...page.data];
      while (page.links?.next) {
        page = await page.next();
        groups.push(...page.data);
      }

      if (!this.isDestroying) {
        this.allGroups = groups;
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    {{#each this.groups as |group|}}
      <ShareReport @group={{group.name}} @query={{@query}} />
    {{else}}
      -
    {{/each}}
  </template>
}
