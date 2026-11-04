/* eslint-disable ember/no-observers */
import { tracked } from "@glimmer/tracking";
import { computed } from "@ember/object";
import { isEmpty } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import type { CategoryFields } from "discourse/models/category";
import Group from "discourse/models/group";
import RestModel, {
  type RestModelClass,
  type RestModelStoreAttrs,
  type RestPayload,
} from "discourse/models/rest";
import Site, { type SiteTopTag } from "discourse/models/site";

/** Raw sideloaded categories retain their required identity without becoming Category instances. */
export type WebHookCategory = CategoryFields & { id: number; name: string };

export interface WebHookEventType {
  id: number;
  name: string;
  group?: string | null;
}

/** Index extras carry catalogues; show extras may contain only categories. */
export interface WebHookExtrasAttrs {
  categories?: WebHookCategory[] | null;
  content_types?: { id: number; name: string }[];
  default_event_types?: WebHookEventType[];
  delivery_statuses?: { id: number; name: string }[];
  grouped_event_types?: Record<string, WebHookEventType[]> | [];
}

class WebHookExtras {
  @tracked categories: WebHookCategory[];
  declare content_types: { id: number; name: string }[];
  declare default_event_types: WebHookEventType[];
  declare delivery_statuses: { id: number; name: string }[];
  declare grouped_event_types: Record<string, WebHookEventType[]> | [];

  constructor(args: WebHookExtrasAttrs) {
    this.categories = args.categories || [];
    this.content_types = args.content_types || [];
    this.default_event_types = args.default_event_types || [];
    this.delivery_statuses = args.delivery_statuses || [];
    this.grouped_event_types = args.grouped_event_types || [];
  }

  get categoriesById() {
    if (this.categories) {
      return new Map(this.categories.map((c) => [c.id, c]));
    }
  }

  addCategories(categories: WebHookCategory[]) {
    this.categories = uniqueItemsFromArray(
      this.categories.concat(categories),
      "id"
    );
  }

  findCategoryById(id: number) {
    return this.categoriesById?.get(id);
  }
}

/** Serialized tags and names/IDs written by the tag selector. */
export type WebHookTag =
  | (SiteTopTag & {
      topic_count?: number;
      staff?: boolean;
      description?: string | null;
      description_cooked?: string | null;
      localizations?: {
        id: number;
        tag_id: number;
        locale: string;
        name: string;
        description: string | null;
        description_cooked: string | null;
      }[];
    })
  | string
  | number;

export interface WebHookFields {
  id?: number;
  payload_url: string;
  secret: string | null;
  category_ids: number[];
  group_ids: number[];
  tags?: WebHookTag[] | null;
  extras?: WebHookExtras;
}

/** Category writes require resolved selections even though reads can contain missing IDs. */
export type WebHookCreateAttrs<M = WebHook> = Partial<Omit<M, "categories">> &
  RestModelStoreAttrs &
  RestPayload & { categories?: WebHookCategory[] };

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface WebHook extends WebHookFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class WebHook extends RestModel {
  declare static create: <C extends RestModelClass>(
    this: C,
    attrs?: WebHookCreateAttrs<InstanceType<C>>
  ) => InstanceType<C>;

  static ExtrasClass = WebHookExtras;
  content_type = 1; // json
  last_delivery_status = 1; // inactive
  wildcard_web_hook = false;
  verify_certificate = true;
  active = false;

  web_hook_event_types: WebHookEventType[] | null = null;

  /**
   * Group names, or a comma-separated string of them when set by a group selector.
   */
  group_names: string[] | string | null = null;

  @computed("wildcard_web_hook")
  get wildcard() {
    return this.wildcard_web_hook ? "wildcard" : "individual";
  }

  set wildcard(value: "wildcard" | "individual") {
    this.set("wildcard_web_hook", value === "wildcard");
  }

  @computed("category_ids")
  get categories(): (WebHookCategory | undefined)[] {
    return (this.category_ids || []).map((id) =>
      this.extras!.findCategoryById(id)
    );
  }

  set categories(value: WebHookCategory[]) {
    this.extras ||= new WebHookExtras({});
    this.extras.addCategories(value);

    this.set(
      "category_ids",
      value.map((c) => c.id)
    );
  }

  @computed("wildcard_web_hook", "web_hook_event_types.[]")
  get description() {
    let desc = "";

    this.web_hook_event_types?.forEach((type) => {
      const name = `${type.name.toLowerCase()}_event`;
      desc += desc !== "" ? `, ${name}` : name;
    });

    return this.wildcard_web_hook ? "*" : desc;
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
      }, [] as string[])
    );
  }

  groupFinder(term: string) {
    return Group.findAll({ term, ignore_automatic: false });
  }

  createProperties(): {
    payload_url: string;
    content_type: number;
    secret: string;
    wildcard_web_hook: boolean;
    verify_certificate: boolean;
    active: boolean;
    web_hook_event_type_ids: (number | null)[];
    category_ids: (number | null)[];
    tag_ids: (string | number | null)[];
    group_ids: (number | null)[];
  } {
    const types = this.web_hook_event_types;
    // Saving assumes selected category IDs resolve through extras, as in the original model.
    const categoryIds = this.categories.map((c) => c!.id);
    const tags = this.tags;

    // Hack as {{group-selector}} accepts a comma-separated string as data source, but
    // we use an array to populate the datasource above.
    const groupsFilter = this.group_names;
    const groupNames =
      typeof groupsFilter === "string" ? groupsFilter.split(",") : groupsFilter;

    // isEmpty handles null selections before the original map/includes calls.
    return {
      payload_url: this.payload_url,
      content_type: this.content_type,
      secret: this.secret ?? "",
      wildcard_web_hook: this.wildcard_web_hook,
      verify_certificate: this.verify_certificate,
      active: this.active,
      web_hook_event_type_ids: isEmpty(types)
        ? [null]
        : types!.map((type) => type.id),
      category_ids: isEmpty(categoryIds) ? [null] : categoryIds,
      tag_ids: isEmpty(tags)
        ? [null]
        : tags!.map((t) => (typeof t === "object" ? t.id : t)),
      group_ids:
        isEmpty(groupNames) || isEmpty(groupNames![0])
          ? [null]
          : Site.currentProp("groups").reduce((groupIds, g) => {
              if (groupNames!.includes(g.name)) {
                groupIds.push(g.id);
              }
              return groupIds;
            }, [] as number[]),
    };
  }

  updateProperties() {
    return this.createProperties();
  }
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    "web-hook": WebHook;
  }

  interface ModelCreateAttrsRegistry {
    "web-hook": WebHookCreateAttrs;
  }
}
