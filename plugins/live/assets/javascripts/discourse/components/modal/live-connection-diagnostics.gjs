import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { clipboardCopy } from "discourse/lib/utilities";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  formatBitrate,
  formatCandidateCounts,
  formatIceError,
  formatReport,
  formatRtt,
} from "../../lib/live/connection-diagnostics.js";

const REFRESH_INTERVAL_MS = 3000;

const ROUTE_ICONS = {
  host: "network-wired",
  stun: "arrow-right-arrow-left",
  "relay-local": "server",
  "relay-remote": "server",
  "relay-both": "server",
  unknown: "circle-question",
};

function peerStatus(peer) {
  const state = peer.connection?.connectionState;
  if (!peer.connection) {
    return peer.expected ? "missing" : "not_needed";
  }
  if (state === "connected") {
    return "connected";
  }
  if (state === "failed" || state === "disconnected" || state === "closed") {
    return "failed";
  }
  return "connecting";
}

function candidateLabel(candidate) {
  if (!candidate) {
    return null;
  }
  return [
    candidate.address &&
      (candidate.port
        ? `${candidate.address}:${candidate.port}`
        : candidate.address),
    candidate.type,
    candidate.protocol?.toUpperCase(),
    candidate.relayProtocol &&
      i18n("live.connection_diagnostics.relay_over", {
        protocol: candidate.relayProtocol.toUpperCase(),
      }),
    candidate.networkType,
  ]
    .filter(Boolean)
    .join(" · ");
}

export default class LiveConnectionDiagnosticsModal extends Component {
  @service liveWebrtc;
  @service toasts;

  @tracked diagnostics = null;
  @tracked probes = null;
  @tracked probing = false;

  #refreshTimer = null;

  constructor() {
    super(...arguments);
    this.refresh();
    this.#refreshTimer = setInterval(
      () => this.#collectPeers(),
      REFRESH_INTERVAL_MS
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    clearInterval(this.#refreshTimer);
  }

  get room() {
    return this.args.model.room;
  }

  get peers() {
    return (this.diagnostics?.peers || [])
      .map((peer) => {
        const status = peerStatus(peer);
        const stats = peer.connection?.stats;
        const pair = stats?.selectedPair;
        const route = stats?.route ?? "unknown";
        const recovery = peer.recovery;

        return {
          key: peer.userId,
          user: {
            username: peer.username,
            avatar_template: peer.avatarTemplate,
          },
          displayName:
            peer.username ||
            i18n("live.connection_diagnostics.unknown_user", {
              id: peer.userId,
            }),
          inRoster: peer.inRoster,
          status,
          statusLabel: i18n(`live.connection_diagnostics.status.${status}`),
          hasConnection: !!peer.connection,
          route,
          routeIcon: ROUTE_ICONS[route],
          routeLabel: i18n(`live.connection_diagnostics.route.${route}`),
          isRelayed: route.startsWith("relay"),
          states: peer.connection
            ? [
                ["connection", peer.connection.connectionState],
                ["ice", peer.connection.iceConnectionState],
                ["gathering", peer.connection.iceGatheringState],
                ["signaling", peer.connection.signalingState],
              ].map(([name, value]) => ({
                label: i18n(`live.connection_diagnostics.states.${name}`),
                value,
              }))
            : [],
          localCandidate: candidateLabel(pair?.local),
          localServer: pair?.local?.url,
          remoteCandidate: candidateLabel(pair?.remote),
          rtt: pair ? formatRtt(pair.currentRoundTripTime) : null,
          bitrate:
            typeof pair?.availableOutgoingBitrate === "number"
              ? formatBitrate(pair.availableOutgoingBitrate)
              : null,
          localCandidates:
            stats && formatCandidateCounts(stats.localCandidates),
          remoteCandidates:
            stats && formatCandidateCounts(stats.remoteCandidates),
          candidatePairs:
            stats &&
            i18n("live.connection_diagnostics.candidate_pairs_value", {
              total: stats.candidatePairs.total,
              succeeded: stats.candidatePairs.succeeded,
              failed: stats.candidatePairs.failed,
            }),
          restarts: i18n("live.connection_diagnostics.restarts_value", {
            count: recovery.restartAttempts,
            max: recovery.maxRestartAttempts,
          }),
          restartsExhausted:
            recovery.restartAttempts >= recovery.maxRestartAttempts &&
            status !== "connected",
          iceErrors: recovery.iceCandidateErrors.map((error) =>
            formatIceError(error)
          ),
        };
      })
      .sort((a, b) => (a.status === "connected") - (b.status === "connected"));
  }

  get connectedCount() {
    return this.peers.filter((peer) => peer.status === "connected").length;
  }

  get expectedCount() {
    return this.peers.filter((peer) => peer.status !== "not_needed").length;
  }

  get summary() {
    return i18n("live.connection_diagnostics.summary", {
      connected: this.connectedCount,
      total: this.expectedCount,
    });
  }

  get relayOnly() {
    return this.diagnostics?.iceTransportPolicy === "relay";
  }

  get probeRows() {
    return (this.probes || []).map((probe) => {
      let status = "failed";
      if (probe.reachable) {
        status = "ok";
      } else if (probe.timedOut) {
        status = "timeout";
      }
      return {
        url: probe.url,
        kind: probe.kind.toUpperCase(),
        relayAddresses: probe.relayAddresses.join(", "),
        publicAddresses: probe.publicAddresses.join(", "),
        missingPublicAddress: probe.udp && !probe.publicAddresses.length,
        status,
        statusLabel: probe.reachable
          ? i18n("live.connection_diagnostics.probe.ok", {
              ms: probe.durationMs,
            })
          : i18n(`live.connection_diagnostics.probe.${status}`),
        // The probe only talks to this one server, so its URL is redundant.
        errors: probe.errors.map((error) =>
          formatIceError(error, { includeUrl: false })
        ),
      };
    });
  }

  get localRows() {
    const local = this.diagnostics?.local;
    if (!local) {
      return [];
    }

    const rows = [
      ["browser", local.userAgent],
      ["platform", local.platform],
      [
        "online",
        local.online
          ? i18n("live.connection_diagnostics.answer_yes")
          : i18n("live.connection_diagnostics.answer_no"),
      ],
      ["cpu_cores", local.hardwareConcurrency],
    ];

    if (local.connection) {
      const { effectiveType, type, downlink, rtt } = local.connection;
      rows.push([
        "network",
        [
          type,
          effectiveType,
          downlink && `${downlink} Mbps`,
          typeof rtt === "number" && `${rtt} ms`,
        ]
          .filter(Boolean)
          .join(" · "),
      ]);
    }

    for (const track of local.localTracks) {
      rows.push([
        track.kind === "video" ? "camera" : "microphone",
        [
          track.label,
          track.readyState,
          track.enabled ? null : i18n("live.connection_diagnostics.disabled"),
          track.muted ? i18n("live.connection_diagnostics.no_signal") : null,
        ]
          .filter(Boolean)
          .join(" · "),
      ]);
    }

    return rows
      .filter(([, value]) => value !== undefined && value !== null)
      .map(([key, value]) => ({
        label: i18n(`live.connection_diagnostics.local.${key}`),
        value,
      }));
  }

  @action
  async refresh() {
    await Promise.all([this.#collectPeers(), this.#probe()]);
  }

  @action
  async copyReport() {
    if (!this.diagnostics) {
      return;
    }
    await clipboardCopy(
      formatReport({ ...this.diagnostics, probes: this.probes })
    );
    this.toasts.success({
      duration: "short",
      data: { message: i18n("live.connection_diagnostics.copied") },
    });
  }

  async #collectPeers() {
    const diagnostics = await this.liveWebrtc.connectionDiagnostics(
      this.room.id
    );
    if (!this.isDestroying) {
      this.diagnostics = diagnostics;
    }
  }

  async #probe() {
    if (this.probing) {
      return;
    }
    this.probing = true;
    try {
      const probes = await this.liveWebrtc.probeIceServers();
      if (!this.isDestroying) {
        this.probes = probes;
      }
    } finally {
      if (!this.isDestroying) {
        this.probing = false;
      }
    }
  }

  <template>
    <DModal
      class="live-connection-diagnostics"
      @closeModal={{@closeModal}}
      @title={{i18n "live.connection_diagnostics.title"}}
    >
      <:body>
        {{#if this.diagnostics}}
          {{#if (or this.peers.length this.relayOnly)}}
            <p class="live-connection-diagnostics__summary">
              {{#if this.peers.length}}
                {{this.summary}}
              {{/if}}
              {{#if this.relayOnly}}
                <span class="live-connection-diagnostics__note">
                  {{i18n "live.connection_diagnostics.relay_only"}}
                </span>
              {{/if}}
            </p>
          {{/if}}

          <section class="live-connection-diagnostics__section">
            <h3>{{i18n "live.connection_diagnostics.peers"}}</h3>
            {{#each this.peers key="key" as |peer|}}
              <div
                class={{dConcatClass
                  "live-connection-diagnostics__peer"
                  (concat "--" peer.status)
                }}
              >
                <div class="live-connection-diagnostics__peer-header">
                  {{#if peer.user.avatar_template}}
                    {{dAvatar peer.user imageSize="small"}}
                  {{/if}}
                  <span class="live-connection-diagnostics__peer-name">
                    {{peer.displayName}}
                  </span>
                  {{#unless peer.inRoster}}
                    <span class="live-connection-diagnostics__note">
                      {{i18n "live.connection_diagnostics.not_in_roster"}}
                    </span>
                  {{/unless}}
                  <span
                    class={{dConcatClass
                      "live-connection-diagnostics__badge"
                      (concat "--" peer.status)
                    }}
                  >{{peer.statusLabel}}</span>
                </div>

                {{#if peer.hasConnection}}
                  <div
                    class={{dConcatClass
                      "live-connection-diagnostics__route"
                      (if peer.isRelayed "--relayed")
                    }}
                  >
                    {{dIcon peer.routeIcon}}
                    {{peer.routeLabel}}
                  </div>

                  <dl class="live-connection-diagnostics__details">
                    {{#each peer.states as |state|}}
                      <dt>{{state.label}}</dt>
                      <dd>{{state.value}}</dd>
                    {{/each}}
                    {{#if peer.localCandidate}}
                      <dt>{{i18n
                          "live.connection_diagnostics.local_candidate"
                        }}</dt>
                      <dd>{{peer.localCandidate}}</dd>
                    {{/if}}
                    {{#if peer.localServer}}
                      <dt>{{i18n "live.connection_diagnostics.via_server"}}</dt>
                      <dd><code>{{peer.localServer}}</code></dd>
                    {{/if}}
                    {{#if peer.remoteCandidate}}
                      <dt>{{i18n
                          "live.connection_diagnostics.remote_candidate"
                        }}</dt>
                      <dd>{{peer.remoteCandidate}}</dd>
                    {{/if}}
                    {{#if peer.rtt}}
                      <dt>{{i18n "live.connection_diagnostics.rtt"}}</dt>
                      <dd>{{peer.rtt}}</dd>
                    {{/if}}
                    {{#if peer.bitrate}}
                      <dt>{{i18n "live.connection_diagnostics.bitrate"}}</dt>
                      <dd>{{peer.bitrate}}</dd>
                    {{/if}}
                    {{#if peer.candidatePairs}}
                      <dt>{{i18n
                          "live.connection_diagnostics.candidate_pairs"
                        }}</dt>
                      <dd>{{peer.candidatePairs}}</dd>
                      <dt>{{i18n
                          "live.connection_diagnostics.local_candidates"
                        }}</dt>
                      <dd><code>{{peer.localCandidates}}</code></dd>
                      <dt>{{i18n
                          "live.connection_diagnostics.remote_candidates"
                        }}</dt>
                      <dd><code>{{peer.remoteCandidates}}</code></dd>
                    {{/if}}
                    <dt>{{i18n "live.connection_diagnostics.restarts"}}</dt>
                    <dd>
                      {{peer.restarts}}
                      {{#if peer.restartsExhausted}}
                        <span class="live-connection-diagnostics__note">
                          {{i18n "live.connection_diagnostics.gave_up"}}
                        </span>
                      {{/if}}
                    </dd>
                  </dl>
                {{/if}}

                {{#if peer.iceErrors.length}}
                  <ul class="live-connection-diagnostics__errors">
                    {{#each peer.iceErrors as |error|}}
                      <li>{{error}}</li>
                    {{/each}}
                  </ul>
                {{/if}}
              </div>
            {{else}}
              <p>{{i18n "live.connection_diagnostics.no_peers"}}</p>
            {{/each}}
          </section>

          <section class="live-connection-diagnostics__section">
            <h3>{{i18n "live.connection_diagnostics.servers"}}</h3>
            {{#if this.probing}}
              <p class="live-connection-diagnostics__note">
                {{i18n "live.connection_diagnostics.probing"}}
              </p>
            {{else}}
              {{#each this.probeRows as |probe|}}
                <div class="live-connection-diagnostics__server">
                  <div class="live-connection-diagnostics__server-header">
                    <span
                      class="live-connection-diagnostics__server-kind"
                    >{{probe.kind}}</span>
                    <code>{{probe.url}}</code>
                    <span
                      class={{dConcatClass
                        "live-connection-diagnostics__badge"
                        (concat "--" probe.status)
                      }}
                    >{{probe.statusLabel}}</span>
                  </div>
                  <dl class="live-connection-diagnostics__details">
                    {{#if probe.relayAddresses}}
                      <dt>{{i18n
                          "live.connection_diagnostics.relay_address"
                        }}</dt>
                      <dd>{{probe.relayAddresses}}</dd>
                    {{/if}}
                    {{#if probe.publicAddresses}}
                      <dt>{{i18n
                          "live.connection_diagnostics.public_address"
                        }}</dt>
                      <dd>{{probe.publicAddresses}}</dd>
                    {{else if probe.missingPublicAddress}}
                      <dt>{{i18n
                          "live.connection_diagnostics.public_address"
                        }}</dt>
                      <dd class="live-connection-diagnostics__warning">
                        {{i18n "live.connection_diagnostics.no_public_address"}}
                      </dd>
                    {{/if}}
                  </dl>
                  {{#if probe.errors.length}}
                    <ul class="live-connection-diagnostics__errors">
                      {{#each probe.errors as |error|}}
                        <li>{{error}}</li>
                      {{/each}}
                    </ul>
                  {{/if}}
                </div>
              {{else}}
                <p>{{i18n "live.connection_diagnostics.no_servers"}}</p>
              {{/each}}
            {{/if}}
          </section>

          <section class="live-connection-diagnostics__section">
            <h3>{{i18n "live.connection_diagnostics.this_device"}}</h3>
            <dl class="live-connection-diagnostics__details">
              {{#each this.localRows as |row|}}
                <dt>{{row.label}}</dt>
                <dd>{{row.value}}</dd>
              {{/each}}
            </dl>
          </section>
        {{else}}
          <div class="spinner small"></div>
        {{/if}}
      </:body>
      <:footer>
        <p class="live-connection-diagnostics__privacy">
          {{i18n "live.connection_diagnostics.privacy_note"}}
        </p>
        <DButton
          class="btn-primary"
          @action={{this.copyReport}}
          @disabled={{not this.diagnostics}}
          @icon="copy"
          @label="live.connection_diagnostics.copy_report"
        />
        <DButton
          class="btn-default"
          @action={{this.refresh}}
          @disabled={{this.probing}}
          @icon="arrows-rotate"
          @label="live.connection_diagnostics.refresh"
        />
      </:footer>
    </DModal>
  </template>
}
