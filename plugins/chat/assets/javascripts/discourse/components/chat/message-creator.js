import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { schedule } from "@ember/runloop";
import discourseDebounce from "discourse-common/lib/debounce";
import { getOwner, setOwner } from "@ember/application";
import { INPUT_DELAY } from "discourse-common/config/environment";
import I18n from "I18n";
import ChatChatable from "discourse/plugins/chat/discourse/models/chat-chatable";
import { escapeExpression } from "discourse/lib/utilities";
import { htmlSafe } from "@ember/template";

const MAX_RESULTS = 10;
const USER_PREFIX = "@";
const CHANNEL_PREFIX = "#";
const CHANNEL_TYPE = "channel";
const USER_TYPE = "user";

class Search {
  @service("chat-api") api;
  @service chat;
  @service chatChannelsManager;

  @tracked loading = false;
  @tracked value = [];
  @tracked query = "";

  constructor(owner, options = {}) {
    setOwner(this, owner);

    options.preload ??= false;
    options.onlyUsers ??= false;

    if (!options.term && !options.preload) {
      return;
    }

    if (!options.term && options.preload) {
      this.value = this.#loadExistingChannels();
      return;
    }

    this.loading = true;

    this.api
      .chatables({ term: options.term })
      .then((results) => {
        let chatables = [
          ...results.users,
          ...results.direct_message_channels,
          ...results.category_channels,
        ];

        if (options.excludeUserId) {
          chatables = chatables.filter(
            (item) => item.identifier !== `u-${options.excludeUserId}`
          );
        }

        this.value = chatables
          .map((item) => {
            const chatable = ChatChatable.create(item);
            chatable.tracking = this.#injectTracking(chatable);
            return chatable;
          })
          .slice(0, MAX_RESULTS);
      })
      .catch(() => (this.value = []))
      .finally(() => (this.loading = false));
  }

  #loadExistingChannels() {
    return this.chatChannelsManager.allChannels
      .map((channel) => {
        if (channel.chatable?.users?.length === 1) {
          return ChatChatable.createUser(channel.chatable.users[0]);
        }
        const chatable = ChatChatable.createChannel(channel);
        chatable.tracking = channel.tracking;
        return chatable;
      })
      .filter(Boolean)
      .slice(0, MAX_RESULTS);
  }

  #injectTracking(chatable) {
    switch (chatable.type) {
      case CHANNEL_TYPE:
        return this.chatChannelsManager.allChannels.find(
          (channel) => channel.id === chatable.model.id
        )?.tracking;
        break;
      case "user":
        return this.chatChannelsManager.directMessageChannels.find(
          (channel) =>
            channel.chatable.users.length === 1 &&
            channel.chatable.users[0].id === chatable.model.id
        )?.tracking;
        break;
    }
  }
}

export default class ChatMessageCreator extends Component {
  @service("chat-api") api;
  @service("chat-channel-composer") composer;
  @service chat;
  @service site;
  @service router;
  @service currentUser;

  @tracked selection = new TrackedArray();
  @tracked activeSelection = new TrackedArray();
  @tracked query = "";
  @tracked queryElement = null;
  @tracked loading = false;
  @tracked activeSelectionIdentifiers = new TrackedArray();
  @tracked selectedIdentifiers = [];
  @tracked _activeContentIdentifier = null;

  get placeholder() {
    if (this.hasSelectedUsers) {
      return I18n.t("chat.new_message_modal.user_search_placeholder");
    } else {
      return I18n.t("chat.new_message_modal.default_search_placeholder");
    }
  }

  get showFooter() {
    return this.showShortcut || this.hasSelectedUsers;
  }

  get showContent() {
    if (this.hasSelectedUsers && !this.query.length) {
      return false;
    }

    return true;
  }

  get shortcutLabel() {
    let username;

    if (this.activeContent?.type === USER_TYPE) {
      username = this.activeContent.model.username;
    } else {
      username = this.activeContent.model.chatable.users[0].username;
    }

    return htmlSafe(
      I18n.t("chat.new_message_modal.add_user_long", {
        username: escapeExpression(username),
      })
    );
  }

  get showShortcut() {
    return (
      !this.hasSelectedUsers &&
      this.content?.value?.length &&
      this.site.desktopView &&
      (this.activeContent?.type === USER_TYPE ||
        this.activeContent?.isSingleUserChannel)
    );
  }

  get activeContentIdentifier() {
    return (
      this._activeContentIdentifier ||
      this.content.value.find((content) => content.enabled)?.identifier
    );
  }

  get hasSelectedUsers() {
    return this.selection.some((s) => s.type === USER_TYPE);
  }

  get activeContent() {
    return this.content.value.findBy(
      "identifier",
      this.activeContentIdentifier
    );
  }

  set activeContent(content) {
    if (!content?.enabled) {
      return;
    }

    this._activeContentIdentifier = content?.identifier;
  }

  get selectionIdentifiers() {
    return this.selection.mapBy("identifier");
  }

  get openChannelLabel() {
    const users = this.selection.mapBy("model");

    return I18n.t("chat.placeholder_users", {
      commaSeparatedNames: users
        .map((u) => u.name || u.username)
        .join(I18n.t("word_connector.comma")),
    });
  }

  @cached
  get content() {
    let term = this.query;

    if (term?.length) {
      if (this.hasSelectedUsers && term.startsWith(CHANNEL_PREFIX)) {
        term = term.replace(/^#/, USER_PREFIX);
      }

      if (this.hasSelectedUsers && !term.startsWith(USER_PREFIX)) {
        term = USER_PREFIX + term;
      }
    }

    return new Search(getOwner(this), {
      term,
      preload: !this.selection?.length,
      onlyUsers: this.hasSelectedUsers,
      excludeUserId: this.hasSelectedUsers ? this.currentUser?.id : null,
    });
  }

  @action
  onFilter(term) {
    this._activeContentIdentifier = null;
    this.activeSelectionIdentifiers = [];
    this.query = term;
  }

  @action
  setQueryElement(element) {
    this.queryElement = element;
  }

  @action
  focusInput() {
    schedule("afterRender", () => {
      this.queryElement.focus();
    });
  }

  @action
  handleKeydown(event) {
    if (event.key === "Escape") {
      if (this.activeSelectionIdentifiers.length > 0) {
        this.activeSelectionIdentifiers = [];
        event.preventDefault();
        event.stopPropagation();
        return;
      }
    }

    if (event.key === "a" && (event.metaKey || event.ctrlKey)) {
      this.activeSelectionIdentifiers = this.selection.mapBy("identifier");
      return;
    }

    if (event.key === "Enter") {
      if (this.activeSelectionIdentifiers.length > 0) {
        this.activeSelectionIdentifiers.forEach((identifier) => {
          this.removeSelection(identifier);
        });
        this.activeSelectionIdentifiers = [];
        event.preventDefault();
        return;
      } else if (this.activeContentIdentifier) {
        this.toggleSelection(this.activeContentIdentifier, {
          shiftKey: event.shiftKey,
        });
        event.preventDefault();
        return;
      } else if (this.query?.length === 0) {
        this.openChannel(this.selection);
        return;
      }
    }

    if (event.key === "ArrowDown" && this.content.value.length > 0) {
      this.activeSelectionIdentifiers = [];
      this._activeContentIdentifier = this.#getNextContent()?.identifier;
      event.preventDefault();
      return;
    }

    if (event.key === "ArrowUp" && this.content.value.length > 0) {
      this.activeSelectionIdentifiers = [];
      this._activeContentIdentifier = this.#getPreviousContent()?.identifier;
      event.preventDefault();
      return;
    }

    const digit = this.#getDigit(event.code);
    if (event.shiftKey && digit) {
      this._activeContentIdentifier = this.content.objectAt(
        digit - 1
      )?.identifier;
      event.preventDefault();
      return;
    }

    if (event.target.selectionEnd !== 0 || event.target.selectionStart !== 0) {
      return;
    }

    if (event.key === "Backspace" && this.selection.length) {
      if (!this.activeSelectionIdentifiers.length) {
        this.activeSelectionIdentifiers = [this.#getLastSelection().identifier];
        event.preventDefault();
        return;
      } else {
        this.activeSelectionIdentifiers.forEach((identifier) => {
          this.removeSelection(identifier);
        });
        this.activeSelectionIdentifiers = [];
        event.preventDefault();
        return;
      }
    }

    if (event.key === "ArrowLeft") {
      this._activeContentIdentifier = null;
      this.activeSelectionIdentifiers = [
        this.#getPreviousSelection()?.identifier,
      ].filter(Boolean);
      event.preventDefault();
      return;
    }

    if (event.key === "ArrowRight") {
      this._activeContentIdentifier = null;
      this.activeSelectionIdentifiers = [
        this.#getNextSelection()?.identifier,
      ].filter(Boolean);
      event.preventDefault();
      return;
    }
  }

  @action
  replaceActiveSelection(selection) {
    this.activeSelection.clear();
    this.activeSelection.push(selection.identifier);
  }

  @action
  handleInput(event) {
    discourseDebounce(this, this.onFilter, event.target.value, INPUT_DELAY);
  }

  @action
  toggleSelection(identifier, options = {}) {
    if (this.selectionIdentifiers.includes(identifier)) {
      this.removeSelection(identifier, options);
    } else {
      this.addSelection(identifier, options);
    }

    this.focusInput();
  }

  @action
  removeSelection(identifier) {
    this.selection = this.selection.filter(
      (selection) => selection.identifier !== identifier
    );

    this.#handleSelectionChange();
  }

  @action
  addSelection(identifier, options = {}) {
    let selection = this.content.value.findBy("identifier", identifier);

    if (!selection || !selection.enabled) {
      return;
    }

    if (selection.type === CHANNEL_TYPE && !selection.isSingleUserChannel) {
      this.openChannel([selection]);
      return;
    }

    if (!this.hasSelectedUsers && !options.shiftKey && !this.site.mobileView) {
      this.openChannel([selection]);
      return;
    }

    if (selection.isSingleUserChannel) {
      const user = selection.model.chatable.users[0];
      selection = new ChatChatable({
        identifier: `u-${user.id}`,
        type: USER_TYPE,
        model: user,
      });
    }

    this.selection = [
      ...this.selection.filter((s) => s.type !== CHANNEL_TYPE),
      selection,
    ];
    this.#handleSelectionChange();
  }

  @action
  openChannel(selection) {
    if (selection.length === 1 && selection[0].type === CHANNEL_TYPE) {
      const channel = selection[0].model;
      this.router.transitionTo("chat.channel", ...channel.routeModels);
      this.args.onClose?.();
      return;
    }

    const users = selection.filterBy("type", USER_TYPE).mapBy("model");
    this.chat
      .upsertDmChannelForUsernames(users.mapBy("username"))
      .then((channel) => {
        this.router.transitionTo("chat.channel", ...channel.routeModels);
        this.args.onClose?.();
      });
  }

  #handleSelectionChange() {
    this.query = "";
    this.activeSelectionIdentifiers = [];
    this._activeContentIdentifier = null;
  }

  #getPreviousSelection() {
    return this.#getPrevious(
      this.selection,
      this.activeSelectionIdentifiers?.[0]
    );
  }

  #getNextSelection() {
    return this.#getNext(this.selection, this.activeSelectionIdentifiers?.[0]);
  }

  #getLastSelection() {
    return this.selection[this.selection.length - 1];
  }

  #getPreviousContent() {
    return this.#getPrevious(this.content.value, this.activeContentIdentifier);
  }

  #getNextContent() {
    return this.#getNext(this.content.value, this.activeContentIdentifier);
  }

  #getNext(list, currentIdentifier = null) {
    if (list.length === 0) {
      return null;
    }

    list = list.filterBy("enabled");

    if (currentIdentifier) {
      const currentIndex = list.mapBy("identifier").indexOf(currentIdentifier);

      if (currentIndex < list.length - 1) {
        return list.objectAt(currentIndex + 1);
      } else {
        return list[0];
      }
    } else {
      return list[0];
    }
  }

  #getPrevious(list, currentIdentifier = null) {
    if (list.length === 0) {
      return null;
    }

    list = list.filterBy("enabled");

    if (currentIdentifier) {
      const currentIndex = list.mapBy("identifier").indexOf(currentIdentifier);

      if (currentIndex > 0) {
        return list.objectAt(currentIndex - 1);
      } else {
        return list.objectAt(list.length - 1);
      }
    } else {
      return list.objectAt(list.length - 1);
    }
  }

  #getDigit(input) {
    if (typeof input === "string") {
      const match = input.match(/Digit(\d+)/);
      if (match) {
        return parseInt(match[1], 10);
      }
    }
    return false;
  }
}
