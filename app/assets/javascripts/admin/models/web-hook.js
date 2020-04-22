import { isEmpty } from "@ember/utils";
import RestModel from "discourse/models/rest";
import Category from "discourse/models/category";
import Group from "discourse/models/group";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Site from "discourse/models/site";

export default RestModel.extend({
  content_type: 1, // json
  last_delivery_status: 1, // inactive
  wildcard_web_hook: false,
  verify_certificate: true,
  active: false,
  web_hook_event_types: null,
  groupsFilterInName: null,

  @discourseComputed("wildcard_web_hook")
  webHookType: {
    get(wildcard) {
      return wildcard ? "wildcard" : "individual";
    },
    set(value) {
      this.set("wildcard_web_hook", value === "wildcard");
    }
  },

  @discourseComputed("category_ids")
  categories(categoryIds) {
    return Category.findByIds(categoryIds);
  },

  @observes("group_ids")
  updateGroupsFilter() {
    const groupIds = this.group_ids;
    this.set(
      "groupsFilterInName",
      Site.currentProp("groups").reduce((groupNames, g) => {
        if (groupIds.includes(g.id)) {
          groupNames.push(g.name);
        }
        return groupNames;
      }, [])
    );
  },

  groupFinder(term) {
    return Group.findAll({ term: term, ignore_automatic: false });
  },

  @discourseComputed("wildcard_web_hook", "web_hook_event_types.[]")
  description(isWildcardWebHook, types) {
    let desc = "";

    types.forEach(type => {
      const name = `${type.name.toLowerCase()}_event`;
      desc += desc !== "" ? `, ${name}` : name;
    });

    return isWildcardWebHook ? "*" : desc;
  },

  createProperties() {
    const types = this.web_hook_event_types;
    const categoryIds = this.categories.map(c => c.id);
    const tagNames = this.tag_names;

    // Hack as {{group-selector}} accepts a comma-separated string as data source, but
    // we use an array to populate the datasource above.
    const groupsFilter = this.groupsFilterInName;
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
        : types.map(type => type.id),
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
            }, [])
    };
  },

  updateProperties() {
    return this.createProperties();
  }
});
