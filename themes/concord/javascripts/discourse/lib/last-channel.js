import { ajax } from "discourse/lib/ajax";
import getURL from "discourse/lib/get-url";
import Category from "discourse/models/category";

const STORAGE_KEY = "concord-last-channel";

// How long the homepage waits on a channel being checked before giving up on
// it for this visit.
const CHECK_TIMEOUT = 5000;

/**
 * Reopens the channel someone was last in when they come back to the site's
 * address. Only a fresh load of the homepage itself is
 * redirected: a link to any other page goes where it says, and the home link
 * inside the app still goes home.
 *
 * Kept per user in local storage, so people sharing a browser don't get each
 * other's channels. A topic counts as being in its category's channel.
 */
export default class LastChannel {
  #saved;

  constructor(owner, currentChannel, user) {
    this.router = owner.lookup("service:router");
    this.keyValueStore = owner.lookup("service:key-value-store");
    this.chat = owner.lookup("service:chat");
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.voiceRooms = owner.lookup("service:live-rooms");
    this.currentChannel = currentChannel;
    this.key = `${STORAGE_KEY}:${user.id}`;
  }

  install() {
    this.#saved = this.keyValueStore.getObject(this.key);
    this.router.one("routeWillChange", (transition) =>
      this.#reopen(transition)
    );
    this.router.on("routeDidChange", () => this.#remember());
  }

  #reopen(transition) {
    const saved = this.#saved;
    if (transition.from || !saved?.type || !isHomepageAddress()) {
      return;
    }

    // Starting another transition aborts the homepage's, so it's never drawn
    // or left in the history.
    const category = saved.type === "forum" && Category.findById(saved.id);
    if (category) {
      this.router.replaceWith(category.path);
      return;
    }

    // Anything else is checked first, so a channel that's gone, or can't be
    // reached right now, falls back to the homepage rather than an error.
    transition.abort();

    let timer;
    const timeout = new Promise((resolve) => {
      timer = setTimeout(resolve, CHECK_TIMEOUT);
    });

    Promise.race([this.#find(saved), timeout])
      .then((url) => {
        if (url) {
          this.router.replaceWith(url);
        } else {
          transition.retry();
        }
      })
      .finally(() => clearTimeout(timer));
  }

  // The channel's current address, or nothing if it can't be opened. Only a
  // channel that's definitely gone is forgotten, not one that failed to load.
  async #find(saved) {
    try {
      const url = await this.#urlFor(saved);
      if (!url) {
        this.#forget();
      }
      return url;
    } catch (error) {
      if ([403, 404].includes(error?.jqXHR?.status)) {
        this.#forget();
      }
    }
  }

  async #urlFor({ type, id, slug, url }) {
    switch (type) {
      case "forum": {
        const [category] = await Category.asyncFindByIds([id]);
        return category?.path;
      }
      case "text": {
        await this.chat?.loadChannels();
        let channel = await this.chatChannelsManager?.find(id, {
          fetchIfNotFound: false,
        });
        if (!channel) {
          const result = await this.chatApi.channel(id);
          channel = this.chatChannelsManager.store(result.channel);
        }
        return `/chat/c/${channel.slugifiedTitle}/${channel.id}`;
      }
      case "tag":
        await ajax(`/tag/${id}/info.json`);
        return url;
      case "voice":
        await this.voiceRooms?.ready;
        return this.voiceRooms?.roomBySlug(slug) && url;
    }
  }

  #remember() {
    const saved = this.#channel();
    if (saved && JSON.stringify(saved) !== JSON.stringify(this.#saved)) {
      this.#saved = saved;
      this.keyValueStore.setObject({ key: this.key, value: saved });
    }
  }

  #channel() {
    const current = this.currentChannel.value;
    const path = (this.router.currentURL || "").split(/[?#]/)[0];

    switch (current?.type) {
      case "text":
        return { type: "text", id: current.channel.id };
      case "forum":
        return categoryChannel(current.category);
      case "topic":
        return (
          !current.topic.isPrivateMessage &&
          categoryChannel(current.topic.category)
        );
      case "tag":
        return { type: "tag", id: current.tag.id, url: path };
      case "voice":
        return { type: "voice", slug: current.room.slug, url: path };
    }
  }

  #forget() {
    this.#saved = null;
    this.keyValueStore.remove(this.key);
  }
}

function categoryChannel(category) {
  return category && { type: "forum", id: category.id };
}

function isHomepageAddress() {
  const trim = (path) => path.replace(/\/+$/, "");
  return (
    trim(window.location.pathname) === trim(getURL("/")) &&
    !window.location.search
  );
}
