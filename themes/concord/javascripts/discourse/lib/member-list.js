import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";

const OPEN_KEY = "concord_member_list_open";
// Enough of a channel's members up front that its online members are found,
// without paging through a huge channel before anything shows.
const EAGER_PAGES = 5;
const ROLE_MEMBER_LIMIT = 1000;

/**
 * Pages through one source of members, all returning plain user JSON.
 */
class MemberPager {
  @tracked users = [];
  @tracked loading = false;
  @tracked done = false;

  loadMore = async () => {
    if (this.loading || this.done) {
      return;
    }

    this.loading = true;
    try {
      const { users, more } = await this.fetchPage(this.page++);
      this.users = [...this.users, ...users];
      this.done = !more;
    } catch {
      this.done = true;
    } finally {
      this.loading = false;
    }
  };

  constructor(fetchPage) {
    this.fetchPage = fetchPage;
    this.page = 0;
  }

  async loadPages(count) {
    for (let i = 0; i < count && !this.done; i++) {
      await this.loadMore();
    }
  }
}

/**
 * Who to show in the member list for the current channel, sorted into
 * sections: each role's online members, then everyone else online, then
 * offline.
 *
 * "Online" means active on the site in the last few minutes, from chat's
 * presence channel, plus the who's-online plugin when it's there.
 */
export default class MemberList {
  @service keyValueStore;
  @service router;
  @service site;

  @tracked open;
  // Small screens show the list as a slide-in instead, which starts closed
  // and closes when the page changes.
  @tracked slideOpen = false;
  @tracked roleMembers = new Map();

  #pagers = new Map();
  #rolesRequested = false;

  constructor(owner, currentChannel) {
    setOwner(this, owner);
    this.currentChannel = currentChannel;
    this.chat = owner.lookup("service:chat");
    this.whosOnline = owner.lookup("service:whos-online");
    this.open = this.keyValueStore.get(OPEN_KEY) !== "false";
    this.router.on("routeDidChange", () => (this.slideOpen = false));
    // A user card opens beneath the slide-in, so make way for it.
    owner
      .lookup("service:app-events")
      .on("card:show", () => (this.slideOpen = false));
  }

  // The same breakpoint core opens its sidebar as a slide-in below.
  get compact() {
    return this.site.mobileView || this.site.narrowDesktopView;
  }

  // A voice channel lists who's in it under its name in the channel list,
  // as in Discord, so it has no member list of its own. Neither does admin.
  get available() {
    return (
      !this.currentChannel.isAdmin &&
      this.currentChannel.value?.type !== "voice"
    );
  }

  get active() {
    return this.available && (this.compact ? this.slideOpen : this.open);
  }

  get onlineUsers() {
    const byId = new Map();

    for (const user of this.chat?.presenceChannel?.users || []) {
      byId.set(user.id, user);
    }
    for (const user of this.whosOnline?.publishedUsers || []) {
      byId.set(user.id, user);
    }

    return [...byId.values()];
  }

  get pager() {
    const current = this.currentChannel.value;
    const key =
      current?.type === "text" ? `text:${current.channel.id}` : "server";

    if (!this.#pagers.has(key)) {
      const pager =
        current?.type === "text"
          ? this.#channelPager(current.channel.id)
          : this.#serverPager();
      this.#pagers.set(key, pager);
      // Out of the render that asked for it, since loading updates state.
      next(() => pager.loadPages(current?.type === "text" ? EAGER_PAGES : 1));
    }

    return this.#pagers.get(key);
  }

  /**
   * @returns {Array<{ id: string, title: string, users: Array }>}
   */
  get sections() {
    if (!this.#rolesRequested) {
      this.#rolesRequested = true;
      next(() => this.#requestRoles());
    }

    const current = this.currentChannel.value;
    const pager = this.pager;
    const placed = new Set();
    const sections = [];

    const take = (users) =>
      users.filter((user) => {
        if (placed.has(user.id)) {
          return false;
        }
        placed.add(user.id);
        return true;
      });

    // A private channel's list only covers its members; elsewhere it's
    // everyone who can see it. Members load a page at a time, so filtering a
    // public channel by them would leave out people further down the pages.
    const memberIds =
      current?.type === "text" && current.channel.chatable?.read_restricted
        ? new Set(pager.users.map((user) => user.id))
        : null;
    const online = this.onlineUsers.filter(
      (user) => !memberIds || memberIds.has(user.id)
    );

    for (const role of this.roles) {
      const ids = this.roleMembers.get(role.name);
      sections.push({
        id: `role-${role.name}`,
        title: role.full_name || role.name,
        users: take(online.filter((user) => ids?.has(user.id))),
      });
    }

    sections.push({ id: "online", title: "online", users: take(online) });
    sections.push({
      id: "offline",
      title: "offline",
      users: take(pager.users),
    });

    return sections.filter((section) => section.users.length);
  }

  get roles() {
    const ids = (settings.member_list_roles || "")
      .split("|")
      .filter(Boolean)
      .map(Number);

    return ids
      .map((id) => this.site.groups.find((group) => group.id === id))
      .filter(Boolean);
  }

  toggle() {
    if (this.compact) {
      this.slideOpen = !this.slideOpen;
      return;
    }

    this.open = !this.open;
    this.keyValueStore.set({ key: OPEN_KEY, value: String(this.open) });
  }

  #channelPager(channelId) {
    return new MemberPager(async (page) => {
      const limit = 50;
      const result = await ajax(`/chat/api/channels/${channelId}/memberships`, {
        data: { offset: page * limit, limit },
      });
      const users = result.memberships.map((membership) => membership.user);
      return { users, more: users.length === limit };
    });
  }

  #serverPager() {
    return new MemberPager(async (page) => {
      const limit = 50;
      const result = await ajax("/directory_items.json", {
        data: { period: "all", order: "days_visited", page, limit },
      });
      const users = result.directory_items.map((item) => item.user);
      return { users, more: users.length === limit };
    });
  }

  // Users don't carry their groups in any of these payloads, so each role's
  // members are fetched once. Roles are meant to be small groups.
  async #requestRoles() {
    const entries = await Promise.all(
      this.roles.map(async (role) => {
        try {
          const result = await ajax(`/groups/${role.name}/members.json`, {
            data: { limit: ROLE_MEMBER_LIMIT },
          });
          const ids = [...result.members, ...(result.owners || [])].map(
            (user) => user.id
          );
          return [role.name, new Set(ids)];
        } catch {
          return [role.name, new Set()];
        }
      })
    );

    this.roleMembers = new Map(entries);
  }
}
