import Service from "@ember/service";
import { isEmpty } from "@ember/utils";
import KeyValueStore from "discourse/lib/key-value-store";

export const BACK_KEY = "back";
export const INFO_ROUTE_NAMESPACE = "discourse_chat_info_route";
export const ORIGINS = {
  channel: "channel",
  browse: "browse",
};

export default class ChatChannelInfoRouteOriginManager extends Service {
  store = new KeyValueStore(INFO_ROUTE_NAMESPACE);

  get origin() {
    const origin = this.store.getObject(BACK_KEY);

    if (origin) {
      return ORIGINS[origin];
    }
  }

  set origin(value) {
    this.store.setObject({ key: BACK_KEY, value });
  }

  get isBrowse() {
    return this.origin === ORIGINS.browse;
  }

  get isChannel() {
    return this.origin === ORIGINS.channel || isEmpty(this.origin);
  }
}
