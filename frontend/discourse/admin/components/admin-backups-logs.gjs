import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel, scheduleOnce } from "@ember/runloop";
import discourseDebounce from "discourse/lib/debounce";
import { i18n } from "discourse-i18n";

export default class AdminBackupsLogs extends Component {
  @tracked formattedLogs = "";

  registerElement = (element) => {
    this.#element = element;
    this.updateLogs();
  };
  updateLogs = () => {
    if (this.args.logs.length === 0) {
      cancel(this.#formatTimer);
      this.#formatTimer = null;
      this.#resetFormattedLogs();
      return;
    }

    this.#formatTimer = discourseDebounce(this, this.#formatLogs, 150);
  };
  #element;
  #formatTimer;
  #lastProcessedLog;
  #processedLogCount = 0;

  #formatLogs = () => {
    const logs = this.args.logs;

    if (logs.length === 0) {
      this.#resetFormattedLogs();
      return;
    }

    if (
      this.#processedLogCount > logs.length ||
      (this.#processedLogCount > 0 &&
        logs[this.#processedLogCount - 1] !== this.#lastProcessedLog)
    ) {
      this.#resetFormattedLogs();
    }

    let appendedLogs = "";
    for (let index = this.#processedLogCount; index < logs.length; index++) {
      const log = logs[index];
      appendedLogs += `[${log.get("timestamp")}] ${log.get("message")}\n`;
    }

    this.formattedLogs += appendedLogs;
    this.#processedLogCount = logs.length;
    this.#lastProcessedLog = logs.at(-1);
    scheduleOnce("afterRender", this, this.#performScroll);
  };

  #performScroll = () => {
    if (this.#element) {
      this.#element.scrollTop = this.#element.scrollHeight;
    }
  };

  willDestroy() {
    cancel(this.#formatTimer);
    this.#element = null;
    super.willDestroy(...arguments);
  }

  #resetFormattedLogs() {
    this.formattedLogs = "";
    this.#processedLogCount = 0;
    this.#lastProcessedLog = null;
  }

  get lastLog() {
    return this.args.logs.at(-1);
  }

  <template>
    <div
      ...attributes
      class="admin-backups-logs"
      {{didInsert this.registerElement}}
      {{didUpdate this.updateLogs @logs.length this.lastLog}}
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
