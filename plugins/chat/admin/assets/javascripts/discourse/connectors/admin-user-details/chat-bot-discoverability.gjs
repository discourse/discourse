import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DToggleSwitch from "discourse/ui-kit/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default class ChatBotDiscoverability extends Component {
  // The server only sends this to admins, for eligible bots, while chat is enabled.
  static shouldRender(args) {
    return args.model.chat_discoverable !== undefined;
  }

  @tracked saving = false;

  @action
  async toggleDiscoverability() {
    const model = this.args.outletArgs.model;
    const discoverable = !model.chat_discoverable;
    model.set("chat_discoverable", discoverable);
    this.saving = true;
    try {
      await ajax(`/chat/admin/bots/${model.id}/discoverability.json`, {
        type: "PUT",
        data: { discoverable },
      });
    } catch (error) {
      model.set("chat_discoverable", !discoverable);
      popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  <template>
    <section class="details chat-bot-discoverability">
      <h1>{{i18n "chat.admin.title"}}</h1>
      <div class="display-row">
        <div class="field">{{i18n "chat.admin.bot_discoverability.label"}}</div>
        <div class="value">
          <DToggleSwitch
            aria-label={{i18n "chat.admin.bot_discoverability.label"}}
            disabled={{this.saving}}
            @state={{@outletArgs.model.chat_discoverable}}
            {{on "click" this.toggleDiscoverability}}
          />
        </div>
        <div class="controls">{{i18n
            "chat.admin.bot_discoverability.description"
          }}</div>
      </div>
    </section>
  </template>
}
