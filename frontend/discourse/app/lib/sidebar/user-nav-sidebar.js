import { cached } from "@glimmer/tracking";
import { getOwner, setOwner } from "@ember/owner";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL, { withoutPrefix } from "discourse/lib/get-url";
import { showCreateInviteModal } from "discourse/lib/invite-modal";
import BaseCustomSidebarPanel from "discourse/lib/sidebar/base-custom-sidebar-panel";
import BaseCustomSidebarSection from "discourse/lib/sidebar/base-custom-sidebar-section";
import BaseCustomSidebarSectionLink from "discourse/lib/sidebar/base-custom-sidebar-section-link";
import { USER_NAV_PANEL } from "discourse/lib/sidebar/panels";
import { i18n } from "discourse-i18n";

/**
 * Preferences tabs registered by plugins. They reach the horizontal nav through
 * the `user-preferences-nav` outlet, which renders markup this panel cannot
 * read, so a plugin that wants its tab in the panel registers it here too.
 */
let additionalPreferencesLinks = [];

export function addUserNavPreferencesLink(link) {
  additionalPreferencesLinks.push(link);
}

// For testing
export function clearAdditionalUserNavPreferencesLinks() {
  additionalPreferencesLinks = [];
}

// Mirrors `components/user-nav.gjs`. The tabs that own a secondary nav become
// sections of their own below, so they are not repeated here — their section
// header stands in for the tab.
const PROFILE_LINKS = [
  {
    // Leads the list: staff open a profile to act on it, and this is the only
    // entry that leaves the profile for somewhere else.
    name: "admin",
    href: ({ user }) => user?.adminPath,
    label: "admin.user.manage_user",
    icon: "wrench",
    displayed: ({ currentUser }) => currentUser?.staff,
  },
  {
    name: "summary",
    route: "user.summary",
    label: "user.summary.title",
    icon: "user",
    displayed: ({ user }) => !user?.profile_hidden,
  },
  {
    name: "badges",
    route: "user.badges",
    label: "badges.title",
    icon: "certificate",
    displayed: ({ controller }) => controller?.showBadges,
  },
];

// Mirrors `templates/user-activity.gjs`.
const ACTIVITY_LINKS = [
  {
    name: "activity-all",
    route: "userActivity.index",
    label: "user.filters.all",
    icon: "bars-staggered",
  },
  {
    name: "activity-topics",
    route: "userActivity.topics",
    label: "user_action_groups.4",
    icon: "list-ul",
  },
  {
    name: "activity-replies",
    route: "userActivity.replies",
    label: "user_action_groups.5",
    icon: "reply",
  },
  {
    name: "activity-read",
    route: "userActivity.read",
    label: "user.read",
    icon: "clock-rotate-left",
    displayed: ({ controller }) => controller?.showRead,
  },
  {
    name: "activity-drafts",
    route: "userActivity.drafts",
    label: "drafts.label",
    icon: "pencil",
    displayed: ({ controller }) => controller?.showDrafts,
    count: ({ currentUser }) => currentUser?.draft_count,
  },
  {
    name: "activity-pending",
    route: "userActivity.pending",
    icon: "clock",
    displayed: ({ user }) => user?.pending_posts_count > 0,
    text: ({ user }) =>
      i18n("pending_posts.label_with_count", {
        count: user.pending_posts_count,
      }),
  },
  {
    name: "activity-likes",
    route: "userActivity.likesGiven",
    label: "user_action_groups.1",
    icon: "heart",
  },
  {
    name: "activity-bookmarks",
    route: "userActivity.bookmarks",
    label: "user_action_groups.3",
    icon: "bookmark",
    displayed: ({ controller }) => controller?.showBookmarks,
  },
];

// Mirrors `templates/user-notifications.gjs`.
const NOTIFICATION_LINKS = [
  {
    name: "notifications-all",
    route: "userNotifications.index",
    label: "user.filters.all",
    icon: "bell",
    count: ({ currentUser }) => currentUser?.all_unread_notifications_count,
  },
  {
    name: "notifications-responses",
    route: "userNotifications.responses",
    label: "user_action_groups.5",
    icon: "reply",
  },
  {
    name: "notifications-likes",
    route: "userNotifications.likesReceived",
    label: "user_action_groups.2",
    icon: "heart",
  },
  {
    name: "notifications-mentions",
    route: "userNotifications.mentions",
    label: "user_action_groups.7",
    icon: "at",
    displayed: ({ siteSettings }) => siteSettings?.enable_mentions,
  },
  {
    name: "notifications-edits",
    route: "userNotifications.edits",
    label: "user_action_groups.11",
    icon: "pencil",
  },
  {
    name: "notifications-links",
    route: "userNotifications.links",
    label: "user_action_groups.17",
    icon: "link",
  },
];

// Mirrors `templates/user-invited.gjs`. The counts that template shows come
// from controller state that only exists once the tab has been opened, so the
// plain tab labels are used instead.
const INVITE_LINKS = [
  {
    name: "invites-pending",
    route: "userInvited.show",
    routeParams: ["pending"],
    label: "user.invited.pending_tab",
    icon: "hourglass-start",
  },
  {
    name: "invites-expired",
    route: "userInvited.show",
    routeParams: ["expired"],
    label: "user.invited.expired_tab",
    icon: "circle-xmark",
  },
  {
    name: "invites-redeemed",
    route: "userInvited.show",
    routeParams: ["redeemed"],
    label: "user.invited.redeemed_tab",
    icon: "check",
  },
];

// Mirrors the horizontal nav in `templates/preferences.gjs`.
const PREFERENCES_LINKS = [
  {
    name: "preferences-account",
    route: "preferences.account",
    label: "user.preferences_nav.account",
    icon: "circle-user",
  },
  {
    name: "preferences-security",
    route: "preferences.security",
    label: "user.preferences_nav.security",
    icon: "lock",
  },
  {
    name: "preferences-profile",
    route: "preferences.profile",
    label: "user.preferences_nav.profile",
    icon: "address-card",
  },
  {
    name: "preferences-emails",
    route: "preferences.emails",
    label: "user.preferences_nav.emails",
    icon: "envelope",
  },
  {
    name: "preferences-notifications",
    route: "preferences.notifications",
    label: "user.preferences_nav.notifications",
    icon: "bell",
  },
  {
    name: "preferences-tracking",
    route: "preferences.tracking",
    label: "user.preferences_nav.tracking",
    icon: "plus",
    displayed: ({ user }) => user?.can_change_tracking_preferences !== false,
  },
  {
    name: "preferences-users",
    route: "preferences.users",
    label: "user.preferences_nav.users",
    icon: "users",
  },
  {
    name: "preferences-interface",
    route: "preferences.interface",
    label: "user.preferences_nav.interface",
    icon: "desktop",
  },
  {
    name: "preferences-navigation-menu",
    route: "preferences.navigation-menu",
    label: "user.preferences_nav.navigation_menu",
    icon: "bars",
  },
  {
    name: "preferences-calendar-subscriptions",
    route: "preferences.calendar-subscriptions",
    label: "user.preferences_nav.calendar_subscriptions",
    icon: "calendar-days",
  },
];

// Mirrors `templates/user-private-messages/user.gjs` and `group.gjs`. The links
// are scoped to whichever inbox is selected, so they are built from the live
// `user-private-messages` controller rather than a static list.
function messageLinks({ owner, currentUser, user }) {
  const messages = owner.lookup("controller:user-private-messages");
  const viewingSelf = messages?.viewingSelf ?? currentUser?.id === user?.id;
  const group = messages?.isGroup && messages?.group?.name;

  if (group) {
    return [
      {
        name: "messages-group-latest",
        route: "userPrivateMessages.group.index",
        routeParams: [group],
        label: "categories.latest",
        icon: "envelope",
      },
      ...(viewingSelf
        ? [
            {
              name: "messages-group-new",
              route: "userPrivateMessages.group.new",
              routeParams: [group],
              label: "user.messages.new",
              icon: "circle-exclamation",
              count: (context) =>
                pmCount(context, "new", {
                  inboxFilter: "group",
                  groupName: group,
                }),
            },
            {
              name: "messages-group-unread",
              route: "userPrivateMessages.group.unread",
              routeParams: [group],
              label: "user.messages.unread",
              icon: "circle-plus",
              count: (context) =>
                pmCount(context, "unread", {
                  inboxFilter: "group",
                  groupName: group,
                }),
            },
            {
              name: "messages-group-archive",
              route: "userPrivateMessages.group.archive",
              routeParams: [group],
              label: "user.messages.archive",
              icon: "box-archive",
            },
          ]
        : []),
    ];
  }

  return [
    {
      name: "messages-latest",
      route: "userPrivateMessages.user.index",
      label: "categories.latest",
      icon: "envelope",
    },
    {
      name: "messages-sent",
      route: "userPrivateMessages.user.sent",
      label: "user.messages.sent",
      icon: "reply",
    },
    ...(viewingSelf
      ? [
          {
            name: "messages-new",
            route: "userPrivateMessages.user.new",
            label: "user.messages.new",
            icon: "circle-exclamation",
            count: (context) =>
              pmCount(context, "new", { inboxFilter: "user" }),
          },
          {
            name: "messages-unread",
            route: "userPrivateMessages.user.unread",
            label: "user.messages.unread",
            icon: "circle-plus",
            count: (context) =>
              pmCount(context, "unread", { inboxFilter: "user" }),
          },
        ]
      : []),
    {
      name: "messages-archive",
      route: "userPrivateMessages.user.archive",
      label: "user.messages.archive",
      icon: "box-archive",
    },
  ];
}

function pmCount({ pmTopicTrackingState }, type, opts) {
  return pmTopicTrackingState?.lookupCount(type, opts) ?? 0;
}

// The inboxes `MessagesDropdown` offers, rebuilt for the section's drawer.
function messageInboxes({ user, router, site }) {
  const username = user?.username_lower || user?.username?.toLowerCase();

  if (!username) {
    return [];
  }

  const inboxes = [
    {
      id: "inbox",
      title: i18n("user.messages.inbox"),
      icon: "inbox",
      route: "userPrivateMessages.user",
      models: [username],
      countOpts: { inboxFilter: "user" },
    },
    ...(user.groupsWithMessages || []).map(({ name }) => ({
      id: `group-${name}`,
      title: name,
      icon: "inbox",
      route: "userPrivateMessages.group",
      models: [username, name],
      countOpts: { inboxFilter: "group", groupName: name },
    })),
  ];

  if (site?.can_tag_pms) {
    inboxes.push({
      id: "tags",
      title: i18n("user.messages.tags"),
      icon: "tags",
      route: "userPrivateMessages.tags",
      models: [username],
    });
  }

  return inboxes.filter((inbox) =>
    routeExists(router, inbox.route, inbox.models)
  );
}

// The inbox picker rides in the drawer that leads the messages section. Below
// one inbox there is nothing to pick between.
function messageDrawerLinks(context) {
  const inboxes = messageInboxes(context);

  return inboxes.length > 1
    ? inboxes.map((inbox) => ({
        name: inbox.id,
        route: inbox.route,
        routeParams: inbox.models.slice(1),
        text: inbox.title,
        icon: inbox.icon,
        classNames: "user-nav-sidebar-link --inbox",
        count: inbox.countOpts
          ? (ctx) =>
              pmCount(ctx, "new", inbox.countOpts) +
              pmCount(ctx, "unread", inbox.countOpts)
          : undefined,
      }))
    : [];
}

// The `displayed` predicates delegate to the `user` controller wherever the
// horizontal navs do, since it already owns these rules and is live on every
// route the panel covers.
const NAV_SECTIONS = [
  {
    name: "profile",
    hideSectionHeader: true,
    links: () => PROFILE_LINKS,
  },
  {
    name: "activity",
    title: "user.activity_stream",
    displayed: ({ user, controller }) =>
      !user?.profile_hidden && controller?.showActivityTab,
    links: () => ACTIVITY_LINKS,
  },
  {
    name: "notifications",
    title: "user.notifications",
    displayed: ({ controller }) => controller?.showNotificationsTab,
    links: () => NOTIFICATION_LINKS,
  },
  {
    name: "messages",
    title: "user.private_messages",
    displayed: ({ controller }) => controller?.showPrivateMessages,
    links: messageLinks,
    moreLinks: messageDrawerLinks,
    moreLinksPosition: "start",
    moreLinksTriggerPrefixType: "icon",
    moreLinksTriggerPrefixValue: "inbox",
    moreLinksTriggerSuffixType: "icon",
    moreLinksTriggerSuffixValue: "chevron-down",
    // The trigger names the current inbox, so it must not also be listed above.
    moreLinksHoistActiveLink: false,
    moreLinksTriggerText: ({ owner }) => {
      const messages = owner.lookup("controller:user-private-messages");

      return messages?.isGroup && messages?.group?.name
        ? messages.group.name
        : i18n("user.messages.inbox");
    },
    headerActionsIcon: "plus",
    headerActions: ({ owner, controller }) =>
      controller?.showPrivateMessages && controller?.viewingSelf
        ? [
            {
              id: "new-message",
              title: i18n("user.new_private_message"),
              action: () => owner.lookup("service:composer").openNewMessage({}),
            },
          ]
        : [],
  },
  {
    name: "invites",
    title: "user.invited.title",
    // Mirrors `can_see_invite_details` in `routes/user-invited.js`.
    displayed: ({ controller, currentUser, user }) =>
      controller?.canInviteToForum &&
      (currentUser?.staff || currentUser?.id === user?.id),
    links: () => INVITE_LINKS,
    headerActionsIcon: "plus",
    headerActions: ({ owner, controller, currentUser, user }) =>
      controller?.canInviteToForum && currentUser?.id === user?.id
        ? [
            {
              id: "create-invite",
              title: i18n("user.invited.create"),
              action: () => {
                // `showCreateInviteModal` picks the right modal variant for
                // the site; it just needs something owned to look up from, and
                // reads `model.editing` even when opened fresh.
                const context = {};
                setOwner(context, owner);
                showCreateInviteModal(context, { model: { invites: [] } });
              },
            },
          ]
        : [],
  },
  {
    name: "preferences",
    title: "user.preferences.title",
    // Staff can open someone else's preferences, so this follows `can_edit`
    // rather than "is this me".
    displayed: ({ user }) => !!user?.can_edit,
    links: () => [...PREFERENCES_LINKS, ...additionalPreferencesLinks],
  },
];

/**
 * Routes differ between deploys, and a plugin route may not be installed, so
 * anything the router cannot build a URL for is dropped rather than left to
 * throw from `<LinkTo>` while the sidebar renders.
 */
export function routeExists(router, route, models = []) {
  try {
    router.urlFor(route, ...models);
    return true;
  } catch {
    return false;
  }
}

/**
 * `resetNamespace` routes such as `userActivity` and `preferences` keep `user`
 * as their parent even though their names don't show it, so walking the
 * RouteInfo chain catches every tab — including ones added by plugins.
 */
export function isUserRoute(routeInfo) {
  for (let info = routeInfo; info; info = info.parent) {
    if (info.name === "user") {
      return true;
    }
  }

  return false;
}

// The `user` controller owns the nav visibility rules and holds the user being
// viewed, which is not necessarily the current user.
function navContext(owner) {
  const controller = owner.lookup("controller:user");

  return {
    owner,
    controller,
    user: controller?.model,
    currentUser: owner.lookup("service:current-user"),
    pmTopicTrackingState: owner.lookup("service:pm-topic-tracking-state"),
    router: owner.lookup("service:router"),
    site: owner.lookup("service:site"),
    siteSettings: owner.lookup("service:site-settings"),
  };
}

function resolveLink(link, context) {
  // Unread state is tracked for the current user only, so it says nothing
  // about the person whose profile this is.
  const viewingSelf = context.currentUser?.id === context.user?.id;
  const href = typeof link.href === "function" ? link.href(context) : link.href;

  return {
    ...link,
    count: viewingSelf && link.count ? link.count(context) : 0,
    showCount: context.currentUser?.sidebarShowCountOfNewItems,
    // `<LinkTo>` marks a route-backed link active by itself; an href link has
    // to report it. Left undefined otherwise, since a boolean here would also
    // override the router's answer for the route-backed ones.
    currentWhen: href
      ? !!context.router.currentURL?.startsWith(withoutPrefix(href))
      : undefined,
    href,
    models: [context.user.username, ...(link.routeParams || [])],
    text:
      typeof link.text === "function"
        ? link.text(context)
        : link.text || i18n(link.label),
  };
}

class UserNavSectionLink extends BaseCustomSidebarSectionLink {
  constructor(linkConfig) {
    super(...arguments);
    this.linkConfig = linkConfig;
  }

  get name() {
    return `user-nav-${this.linkConfig.name}`;
  }

  get classNames() {
    return this.linkConfig.classNames || "user-nav-sidebar-link";
  }

  // Count when the viewer asked for counts, a plain dot otherwise — the same
  // trade the community section's links make.
  get badgeText() {
    return this.linkConfig.showCount && this.linkConfig.count;
  }

  get suffixCSSClass() {
    return "unread";
  }

  get suffixType() {
    return "icon";
  }

  get suffixValue() {
    if (!this.linkConfig.showCount && this.linkConfig.count > 0) {
      return "circle";
    }
  }

  get currentWhen() {
    return this.linkConfig.currentWhen;
  }

  get route() {
    return this.linkConfig.route;
  }

  get href() {
    return this.linkConfig.href;
  }

  get models() {
    return this.linkConfig.models;
  }

  get text() {
    return this.linkConfig.text;
  }

  get title() {
    return this.text;
  }

  get prefixType() {
    return "icon";
  }

  get prefixValue() {
    return this.linkConfig.icon;
  }
}

function buildSection(config) {
  return class UserNavSection extends BaseCustomSidebarSection {
    name = `user-nav-${config.name}`;
    hideSectionHeader = !!config.hideSectionHeader;
    // Everything below the header-less list starts folded; the panel's
    // `expandActiveSection` opens whichever one you are inside.
    collapsedByDefault = !config.hideSectionHeader;

    get text() {
      return config.title ? i18n(config.title) : "";
    }

    get links() {
      return this.#buildLinks(config.links);
    }

    get moreLinks() {
      return config.moreLinks ? this.#buildLinks(config.moreLinks) : [];
    }

    get actions() {
      return config.headerActions
        ? config.headerActions(navContext(getOwner(this)))
        : undefined;
    }

    get actionsIcon() {
      return config.headerActionsIcon;
    }

    get moreLinksHoistActiveLink() {
      return config.moreLinksHoistActiveLink ?? true;
    }

    get moreLinksPosition() {
      return config.moreLinksPosition || "end";
    }

    get moreLinksTriggerPrefixType() {
      return config.moreLinksTriggerPrefixType;
    }

    get moreLinksTriggerPrefixValue() {
      return config.moreLinksTriggerPrefixValue;
    }

    get moreLinksTriggerSuffixType() {
      return config.moreLinksTriggerSuffixType;
    }

    get moreLinksTriggerSuffixValue() {
      return config.moreLinksTriggerSuffixValue;
    }

    get moreLinksTriggerText() {
      const { moreLinksTriggerText } = config;

      return typeof moreLinksTriggerText === "function"
        ? moreLinksTriggerText(navContext(getOwner(this)))
        : moreLinksTriggerText;
    }

    get displaySection() {
      if (config.displayed && !config.displayed(navContext(getOwner(this)))) {
        return false;
      }

      return this.links.length > 0 || this.moreLinks.length > 0;
    }

    #buildLinks(builder) {
      const context = navContext(getOwner(this));

      if (!context.user?.username) {
        return [];
      }

      return builder(context)
        .filter((link) => !link.displayed || link.displayed(context))
        .map((link) => resolveLink(link, context))
        .filter(
          (link) =>
            link.href || routeExists(context.router, link.route, link.models)
        )
        .map((link) => new UserNavSectionLink(link));
    }
  };
}

export default class UserNavSidebarPanel extends BaseCustomSidebarPanel {
  key = USER_NAV_PANEL;
  // A hidden panel never renders a switch button and is skipped in combined
  // mode, so it is only ever reachable by being forced — the same way the admin
  // panel behaves.
  hidden = true;
  displayHeader = true;
  filterable = true;
  filterableMinLinks = 10;
  expandActiveSection = true;
  scrollActiveLinkIntoView = true;

  // The panel also serves a user's admin page, which is reachable from the
  // admin area as well as from a profile. Sending someone who arrived from
  // admin back to the forum would drop them somewhere they never were.
  get backLink() {
    const state = getOwnerWithFallback(this).lookup(
      "service:user-nav-sidebar-state-manager"
    );

    return state.enteredFromAdmin
      ? { href: getURL(state.entryURL), label: "sidebar.back_to_admin" }
      : undefined;
  }

  @cached
  get sections() {
    return NAV_SECTIONS.map(buildSection);
  }
}
