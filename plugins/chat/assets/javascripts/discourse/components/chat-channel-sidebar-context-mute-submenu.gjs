import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import {
  MUTE_DURATIONS,
  mutedUntilFromNow,
} from "discourse/plugins/chat/discourse/lib/chat-mute-durations";

export default class ChatChannelSidebarContextMuteSubmenu extends Component {
  @service chatApi;

  muteDurations = MUTE_DURATIONS.map((duration) => ({
    ...duration,
    label: `chat.settings.mute_options.${duration.id}`,
  }));

  get channel() {
    return this.args.data.channel;
  }

  @action
  muteFor(minutes) {
    return this.#mute({ muted: true, muted_until: mutedUntilFromNow(minutes) });
  }

  @action
  muteUntilUnmuted() {
    return this.#mute({ muted: true });
  }

  async #mute(settings) {
    try {
      const result =
        await this.chatApi.updateCurrentUserChannelNotificationsSettings(
          this.channel.id,
          settings
        );
      const membership = this.channel.currentUserMembership;
      membership.muted = result.membership.muted;
      membership.mutedUntil = result.membership.muted_until
        ? new Date(result.membership.muted_until)
        : null;
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.args.close();
    }
  }

  <template>
    <DDropdownMenu as |dropdown|>
      {{#each this.muteDurations as |duration|}}
        <dropdown.item>
          <DButton
            class="chat-channel-sidebar-link-menu__mute-for"
            data-mute-duration={{duration.id}}
            @action={{fn this.muteFor duration.minutes}}
            @label={{duration.label}}
            @title={{duration.label}}
          />
        </dropdown.item>
      {{/each}}

      <dropdown.item>
        <DButton
          class="chat-channel-sidebar-link-menu__mute-channel"
          @action={{this.muteUntilUnmuted}}
          @label="chat.settings.mute_options.until_unmuted"
          @title="chat.settings.mute_options.until_unmuted"
        />
      </dropdown.item>
    </DDropdownMenu>
  </template>
}
