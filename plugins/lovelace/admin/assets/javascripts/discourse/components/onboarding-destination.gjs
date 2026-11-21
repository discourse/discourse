import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import Topic from "discourse/models/topic";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import TopicChooser from "discourse/select-kit/components/topic-chooser";
import { i18n } from "discourse-i18n";
import OnboardingChannelChooser from "./onboarding-channel-chooser.js";

export default class OnboardingDestination extends Component {
  @service siteSettings;

  @tracked _selected = null;

  constructor() {
    super(...arguments);
    this.#loadSelection();
  }

  get content() {
    return this.selectedId && this._selected?.id === this.selectedId
      ? [this._selected]
      : [];
  }

  get label() {
    return i18n(`lovelace.onboarding.links.${this.args.type}`);
  }

  get selectedId() {
    const patterns = {
      category: /^\/c\/(?:.+\/)?(\d+)\/?$/,
      topic: /^\/t\/(?:[^/]+\/)?(\d+)(?:\/|$)/,
      chat: /^\/chat\/c\/(?:[^/]+\/)?(\d+)(?:\/|$)/,
    };
    const match = this.args.value
      ?.split(/[?#]/)[0]
      .match(patterns[this.args.type]);
    return match ? Number(match[1]) : null;
  }

  @action
  selectCategory(id) {
    const category = Category.findById(id);
    this.args.onChange(category ? category.path : "");
  }

  @action
  selectChannel(id, channel) {
    this._selected = channel;
    this.args.onChange(id ? `/chat/c/${channel.slug || "-"}/${id}` : "");
  }

  @action
  selectTopic(id, topic) {
    this._selected = topic;
    this.args.onChange(id ? `/t/${topic.slug || "-"}/${id}` : "");
  }

  async #loadSelection() {
    const id = this.selectedId;
    const type = this.args.type;
    if (!id || this.args.type === "category") {
      return;
    }
    if (this.args.type === "chat" && !this.siteSettings.chat_enabled) {
      return;
    }
    try {
      const selected =
        this.args.type === "topic"
          ? await Topic.find(id, {})
          : (await ajax(`/chat/api/channels/${id}`)).channel;
      if (
        !this.isDestroying &&
        this.args.type === type &&
        this.selectedId === id
      ) {
        this._selected = selected;
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#if (eq @type "category")}}
      <CategoryChooser
        @disabled={{@disabled}}
        @id={{@id}}
        @onChange={{this.selectCategory}}
        @options={{hash
          clearable=true
          allowUncategorized=true
          none="category.choose"
          headerAriaLabel=this.label
        }}
        @value={{this.selectedId}}
      />
    {{else if (eq @type "topic")}}
      <TopicChooser
        @content={{this.content}}
        @disabled={{@disabled}}
        @id={{@id}}
        @onChange={{this.selectTopic}}
        @options={{hash headerAriaLabel=this.label}}
        @value={{this.selectedId}}
      />
    {{else if this.siteSettings.chat_enabled}}
      <OnboardingChannelChooser
        @content={{this.content}}
        @disabled={{@disabled}}
        @id={{@id}}
        @onChange={{this.selectChannel}}
        @options={{hash headerAriaLabel=this.label}}
        @value={{this.selectedId}}
      />
    {{else}}
      <p>{{i18n "lovelace.onboarding.chat_unavailable"}}</p>
    {{/if}}
  </template>
}
