import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { INPUT_DELAY } from "discourse-common/config/environment";
import discourseDebounce from "discourse-common/lib/debounce";
import { i18n } from "discourse-i18n";
import { MODES } from "./constants";
import ChatablesLoader from "./lib/chatables-loader";
import List from "./list";
import ListHandler from "./list-handler";
import SearchInput from "./search-input";

export default class ChatMessageCreatorSearch extends Component {
  @service chat;
  @service router;

  @tracked chatables = [];
  @tracked highlightedChatable;
  @tracked term;
  @tracked loading = false;

  get items() {
    const items = [];

    if (this.loading) {
      return items;
    }

    if (!this.term?.length) {
      items.push({
        identifier: "new-group",
        type: "list-action",
        label: i18n("chat.new_message_modal.new_group_chat"),
        enabled: true,
        icon: "users",
        id: "new-group-chat",
      });
    }

    return [...items, ...this.chatables];
  }

  @action
  prefillAddMembers(item) {
    this.args.onChangeMode(MODES.new_group, [item]);
  }

  @action
  highlightChatable(chatable) {
    this.highlightedChatable = chatable;
  }

  @action
  async selectChatable(item) {
    switch (item.type) {
      case "list-action":
        this.args.onChangeMode(MODES.new_group);
        break;
      case "user":
        if (!item.enabled) {
          return;
        }

        await this.startOneToOneChannel(item.model.username);
        break;
      case "group":
        if (!item.enabled) {
          return;
        }

        this.args.onChangeMode(MODES.new_group, [item]);
        break;
      default:
        this.router.transitionTo("chat.channel", ...item.model.routeModels);
        this.args.close();
        break;
    }
  }

  @action
  onFilter(event) {
    this.chatables = [];
    this.term = event?.target?.value;

    this.searchHandler = discourseDebounce(
      this,
      this.fetch,
      event.target.value,
      INPUT_DELAY
    );
  }

  @action
  async fetch() {
    const loader = new ChatablesLoader(this);
    this.chatables = await loader.search(this.term, {
      preloadChannels: !this.term,
    });

    this.highlightedChatable = this.items[0];
  }

  async startOneToOneChannel(username) {
    try {
      const channel = await this.chat.upsertDmChannel({
        usernames: [username],
      });

      if (!channel) {
        return;
      }

      this.args.close?.();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async startGroupChannel(group) {
    try {
      const channel = await this.chat.upsertDmChannel({ groups: [group] });

      if (!channel) {
        return;
      }

      this.args.close?.();
      this.router.transitionTo("chat.channel", ...channel.routeModels);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <ListHandler
      @items={{this.items}}
      @highlightedItem={{this.highlightedChatable}}
      @onHighlight={{this.highlightChatable}}
      @onSelect={{this.selectChatable}}
      @onShifSelect={{this.prefillAddMembers}}
    >
      <div class="chat-message-creator__search-container">
        <div class="chat-message-creator__search">
          <div
            class="chat-message-creator__section"
            {{didInsert (fn this.fetch null)}}
          >
            <SearchInput @filter={{this.term}} @onFilter={{this.onFilter}} />

            <DButton
              class="btn-flat chat-message-creator__search-input__cancel-button"
              @icon="xmark"
              @action={{@close}}
            />
          </div>

          <List
            @items={{this.items}}
            @highlightedItem={{this.highlightedChatable}}
            @onSelect={{this.selectChatable}}
            @onHighlight={{this.highlightChatable}}
            @onShiftSelect={{this.prefillAddMembers}}
          />
        </div>
      </div>
    </ListHandler>
  </template>
}
