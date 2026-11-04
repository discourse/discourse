import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import EmojiPickerDetached from "discourse/components/emoji-picker/detached";
import DMenu from "discourse/float-kit/components/d-menu";
import DAnimatedEmoji from "discourse/ui-kit/d-animated-emoji";
import DButton from "discourse/ui-kit/d-button";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";
import { reactionGridColumns } from "../../lib/live/reaction-grid.js";

export default class LiveReactionPicker extends Component {
  @service capabilities;
  @service liveReactions;
  @service menu;
  @service site;
  @service siteSettings;

  @tracked hoveredEmoji = null;

  #menuApi = null;

  get emojis() {
    return this.siteSettings.enable_emoji
      ? (this.site.live_reaction_emojis ?? [])
      : [];
  }

  get allowAnyEmoji() {
    return !!this.site.live_reactions_allow_any_emoji;
  }

  get gridStyle() {
    const cells = this.emojis.length + (this.allowAnyEmoji ? 1 : 0);
    const columns = reactionGridColumns(cells, {
      wide: this.capabilities.viewport.sm,
    });
    return trustHTML(`--live-reaction-columns: ${columns}`);
  }

  get title() {
    return this.liveReactions.rateLimited
      ? i18n("live.reactions.rate_limited")
      : i18n("live.reactions.title");
  }

  @action
  hover(emoji, event) {
    if (event.pointerType === "mouse") {
      this.hoveredEmoji = emoji;
    }
  }

  @action
  unhover() {
    this.hoveredEmoji = null;
  }

  @action
  registerMenu(api) {
    this.#menuApi = api;
  }

  // The menu stays open so a burst of applause doesn't need a reopen per clap.
  @action
  react(emoji) {
    this.liveReactions.send(this.args.room.id, emoji);
  }

  // Swaps our menu for the full picker rather than nesting it: a click inside
  // a nested float counts as outside ours, which would tear the picker down.
  @action
  async openEmojiPicker() {
    const trigger = this.#menuApi?.trigger;
    await this.#menuApi?.close();

    await this.menu.show(trigger, {
      identifier: "emoji-picker",
      groupIdentifier: "emoji-picker",
      component: EmojiPickerDetached,
      modalForMobile: true,
      data: {
        context: "live-reactions",
        didSelectEmoji: this.react,
      },
    });
  }

  <template>
    {{#if this.emojis.length}}
      <DMenu
        @ariaLabel={{this.title}}
        @disabled={{this.liveReactions.rateLimited}}
        @icon="far-face-smile"
        @identifier="live-reaction-menu"
        {{! A full row of our larger emoji outgrows the default menu width. }}
        @maxWidth={{500}}
        @onRegisterApi={{this.registerMenu}}
        @placement="top"
        @title={{this.title}}
        @triggerClass="btn-default live-reaction-picker__trigger"
      >
        <:content>
          <div class="live-reaction-picker" style={{this.gridStyle}}>
            {{#each this.emojis as |emoji|}}
              <DButton
                class="btn-transparent live-reaction-picker__emoji"
                data-emoji={{emoji}}
                @action={{fn this.react emoji}}
                @translatedTitle={{emoji}}
                {{on "pointerenter" (fn this.hover emoji)}}
                {{on "pointerleave" this.unhover}}
              >
                {{#if (eq this.hoveredEmoji emoji)}}
                  <DAnimatedEmoji @code={{emoji}} />
                {{else}}
                  {{dEmoji emoji}}
                {{/if}}
              </DButton>
            {{/each}}
            {{#if this.allowAnyEmoji}}
              <DButton
                class="btn-transparent live-reaction-picker__more"
                @action={{this.openEmojiPicker}}
                @icon="discourse-emojis"
                @title="live.reactions.more"
              />
            {{/if}}
          </div>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
