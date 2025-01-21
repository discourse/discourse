import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import discourseComputed from "discourse/lib/decorators";
import Group from "discourse/models/group";
import RestModel from "discourse/models/rest";
import Site from "discourse/models/site";

class WebHookExtras {
  @tracked categories;

  constructor(args) {
    this.categories = args.categories || [];
    this.content_types = args.content_types || [];
    this.default_event_types = args.default_event_types || [];
    this.delivery_statuses = args.delivery_statuses || [];
    this.grouped_event_types = args.grouped_event_types || [];
  }

  addCategories(categories) {
    this.categories = this.categories.concat(categories).uniqBy((c) => c.id);
  }

  get categoriesById() {
    if (this.categories) {
      return new Map(this.categories.map((c) => [c.id, c]));
    }
  }

  findCategoryById(id) {
    return this.categoriesById?.get(id);
  }
}

export default class WebHook extends RestModel {
  static ExtrasClass = WebHookExtras;
  content_type = 1; // json
  last_delivery_status = 1; // inactive
  wildcard_web_hook = false;
  verify_certificate = true;
  active = false;
  web_hook_event_types = null;
  group_names = null;

  @computed("wildcard_web_hook")
  get wildcard() {
    return this.wildcard_web_hook ? "wildcard" : "individual";
  }

  set wildcard(value) {
    this.set("wildcard_web_hook", value === "wildcard");
  }

  @computed("category_ids")
  get categories() {
    return (this.category_ids || []).map((id) =>
      this.extras.findCategoryById(id)
    );
  }

  set categories(value) {
    this.extras ||= new WebHookExtras({});
    this.extras.addCategories(value);

    this.set(
      "category_ids",
      value.map((c) => c.id)
    );
  }

  @observes("group_ids")
  updateGroupsFilter() {
    const groupIds = this.group_ids;
    this.set(
      "group_names",
      Site.currentProp("groups").reduce((groupNames, g) => {
        if (groupIds.includes(g.id)) {
          groupNames.push(g.name);
        }
        return groupNames;
      }, [])
    );
  }

  groupFinder(term) {
    return Group.findAll({ term, ignore_automatic: false });
  }

  @discourseComputed("wildcard_web_hook", "web_hook_event_types.[]")
  description(isWildcardWebHook, types) {
    let desc = "";

    types.forEach((type) => {
      const name = `${type.name.toLowerCase()}_event`;
      desc += desc !== "" ? `, ${name}` : name;
    });

    return isWildcardWebHook ? "*" : desc;
  }

  createProperties() {
    const types = this.web_hook_event_types;
    const categoryIds = this.categories.map((c) => c.id);
    const tagNames = this.tag_names;

    // Hack as {{group-selector}} accepts a comma-separated string as data source, but
    // we use an array to populate the datasource above.
    const groupsFilter = this.group_names;
    const groupNames =
      typeof groupsFilter === "string" ? groupsFilter.split(",") : groupsFilter;

    return {
      payload_url: this.payload_url,
      content_type: this.content_type,
      secret: this.secret,
      wildcard_web_hook: this.wildcard_web_hook,
      verify_certificate: this.verify_certificate,
      active: this.active,
      web_hook_event_type_ids: isEmpty(types)
        ? [null]
        : types.map((type) => type.id),
      category_ids: isEmpty(categoryIds) ? [null] : categoryIds,
      tag_names: isEmpty(tagNames) ? [null] : tagNames,
      group_ids:
        isEmpty(groupNames) || isEmpty(groupNames[0])
          ? [null]
          : Site.currentProp("groups").reduce((groupIds, g) => {
              if (groupNames.includes(g.name)) {
                groupIds.push(g.id);
              }
              return groupIds;
            }, []),
    };
  }

  updateProperties() {
    return this.createProperties();
  }
}
