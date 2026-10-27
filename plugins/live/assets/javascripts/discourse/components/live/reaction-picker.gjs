import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

export default class LiveReactionPicker extends Component {
  @service liveReactions;
  @service site;
  @service siteSettings;

  get emojis() {
    return this.siteSettings.enable_emoji
      ? (this.site.live_reaction_emojis ?? [])
      : [];
  }

  get title() {
    return this.liveReactions.rateLimited
      ? i18n("live.reactions.rate_limited")
      : i18n("live.reactions.title");
  }

  // The menu stays open so a burst of applause doesn't need a reopen per clap.
  @action
  react(emoji) {
    this.liveReactions.send(this.args.room.id, emoji);
  }

  <template>
    {{#if this.emojis.length}}
      <DMenu
        @ariaLabel={{this.title}}
        @disabled={{this.liveReactions.rateLimited}}
        @icon="far-face-smile"
        @identifier="live-reaction-menu"
        @placement="top"
        @title={{this.title}}
        @triggerClass="btn-default live-reaction-picker__trigger"
      >
        <:content>
          <div class="live-reaction-picker">
            {{#each this.emojis as |emoji|}}
              <DButton
                class="btn-transparent live-reaction-picker__emoji"
                data-emoji={{emoji}}
                @action={{fn this.react emoji}}
                @translatedTitle={{emoji}}
              >
                {{dEmoji emoji}}
              </DButton>
            {{/each}}
          </div>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
