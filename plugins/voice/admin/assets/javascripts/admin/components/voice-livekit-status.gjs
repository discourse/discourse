import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const STATE_ICONS = {
  ok: "circle-check",
  warning: "triangle-exclamation",
  error: "circle-xmark",
};

const PREFIX = "voice.admin.dashboard.livekit";

export default class VoiceLivekitStatus extends Component {
  @tracked status;
  @tracked loading = true;
  @tracked loadFailed = false;

  constructor() {
    super(...arguments);
    this.load();
  }

  // Pure-mesh installs (no LiveKit setting touched) never see the card.
  get visible() {
    if (this.loading && !this.status) {
      return false;
    }
    if (this.loadFailed) {
      return true;
    }

    const settings = this.status?.settings;
    if (!settings) {
      return false;
    }

    return (
      settings.url_present ||
      settings.api_key_present ||
      settings.api_secret_present ||
      settings.policy !== "disabled"
    );
  }

  get checks() {
    const status = this.status;
    if (!status) {
      return [];
    }

    const checks = [];

    if (status.configured) {
      checks.push({
        state: "ok",
        label: i18n(`${PREFIX}.config_ok`, { policy: status.settings.policy }),
      });
    } else {
      const missing = [];
      if (!status.settings.url_present) {
        missing.push("voice_livekit_url");
      }
      if (!status.settings.api_key_present) {
        missing.push("voice_livekit_api_key");
      }
      if (!status.settings.api_secret_present) {
        missing.push("voice_livekit_api_secret");
      }
      checks.push({
        state: "error",
        label: i18n(`${PREFIX}.config_missing`, {
          settings: missing.join(", "),
        }),
      });
    }

    if (status.token_check) {
      checks.push(
        status.token_check.ok
          ? { state: "ok", label: i18n(`${PREFIX}.token_ok`) }
          : {
              state: "error",
              label: i18n(`${PREFIX}.token_error`, {
                error: status.token_check.error,
              }),
            }
      );
    }

    if (status.server_check) {
      checks.push(
        status.server_check.ok
          ? {
              state: "ok",
              label: i18n(`${PREFIX}.server_ok`, {
                latency: status.server_check.latency_ms,
                count: status.server_check.room_count,
              }),
            }
          : {
              state: "error",
              label: i18n(`${PREFIX}.server_error`, {
                error: status.server_check.error,
              }),
            }
      );
    }

    if (status.last_probe) {
      checks.push({
        state: status.last_probe.ok ? "ok" : "error",
        label: i18n(
          `${PREFIX}.${status.last_probe.ok ? "probe_ok" : "probe_failed"}`
        ),
        at: status.last_probe.checked_at,
      });
    } else if (status.configured) {
      checks.push({ state: "warning", label: i18n(`${PREFIX}.probe_never`) });
    }

    checks.push(
      status.last_webhook_at
        ? {
            state: "ok",
            label: i18n(`${PREFIX}.webhook_received`),
            at: status.last_webhook_at,
          }
        : { state: "warning", label: i18n(`${PREFIX}.webhook_never`) }
    );

    return checks.map((check) => ({
      ...check,
      icon: STATE_ICONS[check.state],
    }));
  }

  // Rendered only until the first webhook arrives. The api_key line is a
  // placeholder on purpose: status payloads never echo setting values.
  get showWebhookConfig() {
    return this.status?.configured && !this.status?.last_webhook_at;
  }

  get webhookConfigSnippet() {
    return [
      "webhook:",
      "  urls:",
      `    - ${this.status.webhook_url}`,
      "  api_key: your_api_key # the value of voice_livekit_api_key",
    ].join("\n");
  }

  get roomRows() {
    return (this.status?.rooms || []).map((room) => {
      const probed = room.livekit_user_ids !== undefined || !!room.error;

      return {
        name: room.name,
        presenceCount: room.presence_user_ids.length,
        livekitCount: room.livekit_user_ids?.length,
        probed,
        error: room.error,
        inSync:
          probed &&
          !room.error &&
          !room.missing_on_livekit?.length &&
          !room.missing_in_presence?.length,
        missingOnLivekit: this.#usernames(room.missing_on_livekit),
        missingInPresence: this.#usernames(room.missing_in_presence),
      };
    });
  }

  @action
  async load({ refreshProbe = false } = {}) {
    this.loading = true;
    this.loadFailed = false;

    try {
      this.status = await ajax(
        `/admin/plugins/voice/livekit/${refreshProbe ? "probe" : "status"}.json`,
        refreshProbe ? { type: "POST" } : {}
      );
    } catch {
      this.loadFailed = true;
    } finally {
      this.loading = false;
    }
  }

  @action
  async refresh() {
    await this.load({ refreshProbe: true });
  }

  #usernames(userIds) {
    if (!userIds?.length) {
      return null;
    }
    return userIds
      .map((id) => this.status.usernames?.[id] || `#${id}`)
      .join(", ");
  }

  <template>
    {{#if this.visible}}
      <div class="voice-livekit-status">
        <div class="voice-livekit-status__header">
          <h3>{{i18n "voice.admin.dashboard.livekit.title"}}</h3>
          <DButton
            class="btn-default btn-small voice-livekit-status__refresh"
            @action={{this.refresh}}
            @disabled={{this.loading}}
            @icon="arrows-rotate"
            @label="voice.admin.dashboard.livekit.refresh"
          />
        </div>

        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.loadFailed}}
            <p class="voice-livekit-status__load-failed">{{i18n
                "voice.admin.dashboard.livekit.load_failed"
              }}</p>
          {{else}}
            <ul class="voice-livekit-status__checks">
              {{#each this.checks as |check|}}
                <li class="voice-livekit-status__check --{{check.state}}">
                  {{dIcon check.icon}}
                  <span>
                    {{check.label}}
                    {{#if check.at}}{{dFormatDate
                        check.at
                        leaveAgo="true"
                      }}{{/if}}
                  </span>
                </li>
              {{/each}}
            </ul>

            {{#if this.showWebhookConfig}}
              <div class="voice-livekit-status__webhook-config">
                <p>{{i18n
                    "voice.admin.dashboard.livekit.webhook_config_hint"
                  }}</p>
                <pre><code>{{this.webhookConfigSnippet}}</code></pre>
              </div>
            {{/if}}

            {{#if this.status.configured}}
              <h4>{{i18n "voice.admin.dashboard.livekit.rooms_title"}}</h4>
              {{#if this.roomRows.length}}
                <table class="d-admin-table voice-livekit-status__rooms">
                  <thead>
                    <tr>
                      <th>{{i18n "voice.admin.dashboard.livekit.room"}}</th>
                      <th>{{i18n
                          "voice.admin.dashboard.livekit.discourse_participants"
                        }}</th>
                      <th>{{i18n
                          "voice.admin.dashboard.livekit.livekit_participants"
                        }}</th>
                      <th>{{i18n
                          "voice.admin.dashboard.livekit.room_status"
                        }}</th>
                    </tr>
                  </thead>
                  <tbody>
                    {{#each this.roomRows as |row|}}
                      <tr class="d-admin-row__content">
                        <td class="d-admin-row__overview">{{row.name}}</td>
                        <td class="d-admin-row__detail">
                          {{row.presenceCount}}
                        </td>
                        <td class="d-admin-row__detail">
                          {{if row.probed row.livekitCount "—"}}
                        </td>
                        <td
                          class="d-admin-row__detail voice-livekit-status__room-diff"
                        >
                          {{#if row.error}}
                            <span class="--error">
                              {{dIcon "circle-xmark"}}
                              {{i18n
                                "voice.admin.dashboard.livekit.room_error"
                                error=row.error
                              }}
                            </span>
                          {{else if row.inSync}}
                            <span class="--ok">
                              {{dIcon "circle-check"}}
                              {{i18n "voice.admin.dashboard.livekit.in_sync"}}
                            </span>
                          {{else if row.probed}}
                            {{#if row.missingOnLivekit}}
                              <div class="--warning">
                                {{dIcon "triangle-exclamation"}}
                                {{i18n
                                  "voice.admin.dashboard.livekit.missing_on_livekit"
                                  users=row.missingOnLivekit
                                }}
                              </div>
                            {{/if}}
                            {{#if row.missingInPresence}}
                              <div class="--warning">
                                {{dIcon "triangle-exclamation"}}
                                {{i18n
                                  "voice.admin.dashboard.livekit.missing_in_presence"
                                  users=row.missingInPresence
                                }}
                              </div>
                            {{/if}}
                          {{else}}
                            —
                          {{/if}}
                        </td>
                      </tr>
                    {{/each}}
                  </tbody>
                </table>
              {{else}}
                <p class="voice-livekit-status__no-rooms">{{i18n
                    "voice.admin.dashboard.livekit.no_rooms"
                  }}</p>
              {{/if}}
            {{/if}}
          {{/if}}
        </DConditionalLoadingSpinner>
      </div>
    {{/if}}
  </template>
}
