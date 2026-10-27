import { tracked } from "@glimmer/tracking";
import EmberObject, { computed } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import deprecated from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import { deepMerge } from "discourse/lib/object";
import { emojiUnescape } from "discourse/lib/text";
import {
  hasTrackedFilter,
  isTrackedTopic,
} from "discourse/lib/topic-list-tracked-filter";
import Category from "discourse/models/category";
import type { RestModelStoreAttrs } from "discourse/models/rest";
import Site from "discourse/models/site";
import type TopicTrackingState from "discourse/models/topic-tracking-state";
import User from "discourse/models/user";
import type SiteSettingsService from "discourse/services/site-settings";
import type StoreService from "discourse/services/store";
import { i18n } from "discourse-i18n";

export interface NavItemContext {
  category?: Category;
  tag?: { id?: number; slug?: string };
  noSubcategories?: boolean;
}

/** Build options preserve filterType and filterMode as distinct inputs. */
export interface NavItemOptions extends NavItemContext {
  tagId?: number;
  currentRouteQueryParams?: Record<string, unknown>;
  /** TODO(typescript-pending): the site-settings factory has no typed setting keys; remove the extension when it declares top_menu. */
  siteSettings?: {
    [K in keyof ReturnType<typeof SiteSettingsService.create>]: unknown;
  } & {
    top_menu: string;
  };
  filterType?: string;
  filterMode?: string;
  skipCategoriesNavItem?: boolean;
}

/** Creation-only state; getters and tracked fields are declared on the class. */
export interface NavItemFields
  extends
    RestModelStoreAttrs,
    Omit<
      NavItemOptions,
      | "tag"
      | "siteSettings"
      | "filterMode"
      | "filterType"
      | "skipCategoriesNavItem"
    > {
  active?: boolean;
  hasIcon?: boolean;
  includeCategoryId?: boolean;
  classNames?: string;
}

/** Filter callbacks are tested for truthiness; existing extensions also return user objects. */
export type ExtraNavItemFilter = (
  category: Category | null | undefined,
  args: NavItemOptions
) => unknown;

/** Direct registrations receive two context arguments; init receives the item first. */
export interface NavItemDescriptor extends Partial<NavItemFields> {
  name: string;
  displayName?: string;
  title?: string;
  href?: string;
  count?: number;
  before?: string;
  customFilter?: ExtraNavItemFilter | null;
  customHref?: (
    category: Category | null | undefined,
    args: NavItemOptions
  ) => string | undefined;
  forceActive?: ExtraNavItemFilter;
  init?: (
    item: ExtraNavItem,
    category: Category | null | undefined,
    args: NavItemOptions
  ) => void;
}

/** The plugin API appends the router before registering the descriptor. */
export interface NavigationBarItem extends Omit<
  NavItemDescriptor,
  "customFilter" | "customHref" | "forceActive" | "init"
> {
  customFilter?: (
    category: Category | null | undefined,
    args: NavItemOptions,
    router: RouterService
  ) => unknown;
  customHref?: (
    category: Category | null | undefined,
    args: NavItemOptions,
    router: RouterService
  ) => string | undefined;
  forceActive?: (
    category: Category | null | undefined,
    args: NavItemOptions,
    router: RouterService
  ) => unknown;
  init?: (
    item: ExtraNavItem,
    category: Category | null | undefined,
    args: NavItemOptions,
    router: RouterService
  ) => void;
}

export type ExtraNavItemPropertiesCallback = (
  this: typeof NavItem,
  filterType: string,
  opts: NavItemOptions
) => Partial<NavItem>;
export type CustomNavItemHrefCallback = (
  this: NavItem,
  item: NavItem
) => string | null | undefined;

// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface NavItem extends NavItemFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class NavItem extends EmberObject {
  static extraArgsCallbacks: ExtraNavItemPropertiesCallback[] = [];
  static customNavItemHrefs: CustomNavItemHrefCallback[] = [];
  static extraNavItemDescriptors: NavItemDescriptor[] = [];

  static pathFor(filterType: string, context: NavItemContext): string {
    let path = getURL("");
    let includesCategoryContext = false;
    let includesTagContext = false;

    if (filterType === "categories") {
      path += "/categories";
      return path;
    }

    const tag = context.tag;
    if (tag?.slug && Site.currentProp("filters").includes(filterType)) {
      includesTagContext = true;

      if (context.category) {
        path += "/tags";
      } else {
        path += "/tag";
      }
    }

    if (context.category) {
      includesCategoryContext = true;
      path += `/c/${Category.slugFor(context.category)}/${context.category.id}`;

      if (context.noSubcategories) {
        path += "/none";
      }
    }

    if (includesTagContext) {
      // use canonical URL format with slug/id when id is available
      path += tag!.id ? `/${tag!.slug}/${tag!.id}` : `/${tag!.slug}`;
    }

    if (includesTagContext || includesCategoryContext) {
      path += "/l";
    }

    path += `/${filterType}`;

    // In the case of top, the nav item doesn't include a period because the
    // period has its own selector just below

    return path;
  }

  /** Create a nav item given a filterType, or null if unavailable. The name is a historical artifact. */
  static fromText(filterType: string, opts?: NavItemOptions): NavItem | null {
    const anonymous = !User.current();

    opts = opts || {};

    if (anonymous) {
      const topMenuItems = Site.currentProp("anonymous_top_menu_items");
      if (!topMenuItems || !topMenuItems.includes(filterType)) {
        return null;
      }
    }

    if (!Category.list() && filterType === "categories") {
      return null;
    }
    if (!Site.currentProp("top_menu_items")!.includes(filterType)) {
      return null;
    }

    // eslint-disable-next-line prefer-const -- Preserve the original declaration in this types-only port.
    let args: Partial<NavItem> = {
      name: filterType,
      hasIcon: filterType === "unread",
    };
    if (opts.category) {
      args.category = opts.category;
    }
    if (opts.tag) {
      args.tag = opts.tag;
    }
    if (opts.currentRouteQueryParams) {
      args.currentRouteQueryParams = opts.currentRouteQueryParams;
    }
    if (opts.noSubcategories) {
      args.noSubcategories = true;
    }
    NavItem.extraArgsCallbacks.forEach((cb) =>
      deepMerge(args, cb.call(this, filterType, opts))
    );

    // TODO(typescript-pending): remove the store assertion when getOwnerWithFallback publishes typed service lookups.
    // eslint-disable-next-line prefer-const -- Preserve the original declaration in this types-only port.
    let store = getOwnerWithFallback(this).lookup("service:store");
    return (store as StoreService).createRecord("nav-item", args);
  }

  static buildList(
    category: Category | undefined,
    args?: NavItemOptions
  ): NavItem[] {
    args = args || {};

    if (category) {
      args.category = category;
    }

    if (!args.siteSettings) {
      deprecated("You must supply `buildList` with a `siteSettings` object", {
        since: "2.6.0",
        id: "discourse.nav-item.built-list-site-settings",
      });
      args.siteSettings = getOwnerWithFallback(this).lookup(
        "service:site-settings"
      );
    }
    let items: (string | NavItem | null)[] =
      args.siteSettings!.top_menu.split("|");

    const user = getOwnerWithFallback(this).lookup("service:current-user");
    if (user?.unified_new_enabled) {
      items = items.filter((item) => item !== "unread");
    }
    const filterType = (args.filterMode || "").split("/").pop()!;

    if (!items.some((i) => filterType === i)) {
      items.push(filterType);
    }

    items = (items as string[])
      .map((i) => NavItem.fromText(i, args))
      .filter((i) => {
        if (i === null) {
          return false;
        }

        if (
          (category || args.skipCategoriesNavItem) &&
          i.name.startsWith("categor")
        ) {
          return false;
        }

        return true;
      });

    const context = {
      category: args.category,
      tag: args.tag,
      tagId: args.tagId,
      noSubcategories: args.noSubcategories,
    };

    // TODO(typescript-pending): remove the descriptor assertion when deepMerge preserves its input shapes.
    const extraItems = NavItem.extraNavItemDescriptors
      .map((descriptor) =>
        ExtraNavItem.create(
          deepMerge({}, context, descriptor) as NavItemDescriptor
        )
      )
      .filter((item) => {
        if (!item.customFilter) {
          return true;
        }
        return item.customFilter(category, args);
      });

    let forceActive = false;

    extraItems.forEach((item) => {
      if (item.init) {
        item.init(item, category, args);
      }

      const before = item.before;
      if (before) {
        let i;
        for (i = 0; i < items.length; i++) {
          if ((items[i] as NavItem).name === before) {
            break;
          }
        }
        items.splice(i, 0, item);
      } else {
        items.push(item);
      }

      if (item.customHref) {
        // The public href contract is string; an untyped extension can still return undefined.
        item.href = item.customHref(category, args) as string;
      } else if (item.href) {
        item.href = getURL(item.href);
      }

      if (item.forceActive && item.forceActive(category, args)) {
        item.active = true;
        forceActive = true;
      } else {
        item.active = undefined;
      }
    });

    if (forceActive) {
      items.forEach((i) => {
        if ((i as NavItem).active === undefined) {
          (i as NavItem).active = false;
        }
      });
    }
    return items as NavItem[];
  }

  @service declare topicTrackingState: TopicTrackingState;
  @service declare currentUser: User | null;

  @tracked name!: string;
  @tracked tag?: NavItemContext["tag"];

  @tracked _title?: string;
  @tracked _displayName?: string;

  @tracked _filterTypeOverride?: string;

  @dependentKeyCompat
  get filterType() {
    if (this._filterTypeOverride !== undefined) {
      return this._filterTypeOverride;
    }
    return this.name;
  }

  set filterType(value: string) {
    this._filterTypeOverride = value;
  }

  @dependentKeyCompat
  get title() {
    if (this._title) {
      return this._title;
    }

    let nameKey = this.name.replace("/", ".");

    if (nameKey === "new" && this.currentUser?.unified_new_enabled) {
      nameKey = "unified_new";
    }

    return i18n("filters." + nameKey + ".help", {});
  }

  set title(value: string) {
    this._title = value;
  }

  @dependentKeyCompat
  get displayName() {
    if (this._displayName) {
      return this._displayName;
    }

    let count = this.count || 0;

    if (
      this.name === "latest" &&
      (Site.currentProp("desktopView") || this.tag !== undefined)
    ) {
      count = 0;
    }

    // eslint-disable-next-line prefer-const -- Preserve the original declaration in this types-only port.
    let extra = { count };
    const titleKey = count === 0 ? ".title" : ".title_with_count";

    return emojiUnescape(
      i18n(`filters.${this.name.replace("/", ".") + titleKey}`, extra)
    );
  }

  set displayName(value: string) {
    this._displayName = value;
  }

  @computed("filterType", "category", "noSubcategories", "tag")
  get href(): string {
    let customHref: string | null | undefined = null;

    NavItem.customNavItemHrefs.forEach(function (this: NavItem, cb) {
      customHref = cb.call(this, this);
      if (customHref) {
        return false;
      }
    }, this);

    if (customHref) {
      return getURL(customHref);
    }

    const context = {
      category: this.category,
      noSubcategories: this.noSubcategories,
      tag: this.tag,
    };
    return NavItem.pathFor(this.filterType, context);
  }

  @computed("name", "category", "noSubcategories")
  get filterMode() {
    let mode = "";
    if (this.category) {
      mode += "c/";
      mode += Category.slugFor(this.category);
      if (this.noSubcategories) {
        mode += "/none";
      }
      mode += "/l/";
    }
    return mode + this.name.replace(" ", "-");
  }

  @computed(
    "name",
    "category",
    "tag",
    "noSubcategories",
    "currentRouteQueryParams",
    "topicTrackingState.messageCount"
  )
  get count(): number | undefined {
    return this.topicTrackingState?.lookupCount({
      type: this.name,
      category: this.category,
      tagId: this.tag?.id,
      noSubcategories: this.noSubcategories,
      customFilterFn: hasTrackedFilter(this.currentRouteQueryParams)
        ? isTrackedTopic
        : undefined,
    });
  }
}

/** Erased constructor view permits the writable tracked overrides of computed accessors. */
type WritableNavItemBase = Omit<typeof NavItem, "prototype"> & {
  new (...args: ConstructorParameters<typeof NavItem>): Omit<
    NavItem,
    "href" | "count" | "init"
  > & {
    init(properties?: object): void;
  };
};

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export interface ExtraNavItem extends Pick<
  NavItemDescriptor,
  "before" | "customHref" | "forceActive"
> {
  init: {
    (properties?: object): void;
    (
      item: ExtraNavItem,
      category: Category | undefined,
      args: NavItemOptions
    ): void;
  };
}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export class ExtraNavItem extends (NavItem as WritableNavItemBase) {
  declare static create: <C extends new (...args: never[]) => ExtraNavItem>(
    this: C,
    attrs?: Partial<Omit<InstanceType<C>, "init">> &
      Pick<NavItemDescriptor, "init">
  ) => InstanceType<C>;

  @tracked href!: string;
  @tracked count = 0;

  customFilter: ExtraNavItemFilter | null = null;
}

export function extraNavItemProperties(cb: ExtraNavItemPropertiesCallback) {
  NavItem.extraArgsCallbacks.push(cb);
}

export function customNavItemHref(cb: CustomNavItemHrefCallback) {
  NavItem.customNavItemHrefs.push(cb);
}

export function clearNavItems() {
  NavItem.customNavItemHrefs.length = 0;
  NavItem.extraArgsCallbacks.length = 0;
  NavItem.extraNavItemDescriptors.length = 0;
}

export function addNavItem(item: NavItemDescriptor) {
  NavItem.extraNavItemDescriptors.push(item);
}
