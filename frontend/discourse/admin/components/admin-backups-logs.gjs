import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { scheduleOnce } from "@ember/runloop";
import { i18n } from "discourse-i18n";

export default class AdminBackupsLogs extends Component {
  registerElement = (element) => {
    this.#element = element;
    this.scrollDown();
  };
  scrollDown = () => {
    scheduleOnce("afterRender", this, this.#performScroll);
  };
  #element;

  #performScroll = () => {
    if (this.#element) {
      this.#element.scrollTop = this.#element.scrollHeight;
    }
  };

  get formattedLogs() {
    return this.args.logs
      .map((log) => `[${log.get("timestamp")}] ${log.get("message")}`)
      .join("\n");
  }

  <template>
    <div
      class="admin-backups-logs"
      {{didInsert this.registerElement}}
      {{didUpdate this.scrollDown @logs.length}}
    >
      {{#if this.formattedLogs}}
        <pre>{{this.formattedLogs}}</pre>
      {{else}}
        <p>{{i18n "admin.backups.logs.none"}}</p>
      {{/if}}
      {{#if @status.isOperationRunning}}
        <div class="spinner small"></div>
      {{/if}}
    </div>
  </template>
}
