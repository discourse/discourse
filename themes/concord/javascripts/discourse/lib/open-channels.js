import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const PAGE_SIZE = 100;
// A ceiling for sites with a great many channels, so the page doesn't wait on
// the whole directory.
const MAX_PAGES = 5;

/**
 * Every text channel someone can see is listed, not just the ones they've
 * joined, as in Discord, and opening one joins it. Chat only adds people to
 * channels in the background, so without this a channel shows up late, or
 * never once someone has left it.
 */
export default class OpenChannels {
  constructor(owner) {
    this.router = owner.lookup("service:router");
    this.chat = owner.lookup("service:chat");
    this.chatApi = owner.lookup("service:chat-api");
    this.chatChannelsManager = owner.lookup("service:chat-channels-manager");
    this.chatSubscriptionsManager = owner.lookup(
      "service:chat-subscriptions-manager"
    );
  }

  install() {
    this.#load();
    this.router.on("routeDidChange", () => this.#joinActive());
  }

  // Chat's own channel directory, which only returns channels the user is
  // allowed to see. Followed channels are loaded first, so their unread state
  // comes from chat's usual preload.
  async #load() {
    try {
      await this.chat.loadChannels();

      for (let page = 0; page < MAX_PAGES; page++) {
        const { channels } = await ajax("/chat/api/channels", {
          data: { status: "open", limit: PAGE_SIZE, offset: page * PAGE_SIZE },
        });
        channels.forEach((channel) => this.chatChannelsManager.store(channel));

        if (channels.length < PAGE_SIZE) {
          break;
        }
      }
    } catch {
      // The followed channels are still listed.
    }
  }

  async #joinActive() {
    const channel = this.chat.activeChannel;
    if (
      !channel?.isCategoryChannel ||
      channel.currentUserMembership?.following ||
      // Read-only to them (they can't post in its category), so it's just read.
      !channel.canJoin ||
      !this.router.currentRouteName?.startsWith("chat.channel")
    ) {
      return;
    }

    // Chat's own follow skips a channel with no membership yet, which is
    // every channel the user has never been in.
    try {
      channel.currentUserMembership = await this.chatApi.followChannel(
        channel.id
      );
      this.chatSubscriptionsManager.startChannelSubscription(channel);
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
