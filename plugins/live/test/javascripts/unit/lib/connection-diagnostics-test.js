import { module, test } from "qunit";
import {
  collectPeers,
  formatReport,
  recordIceError,
  routeFor,
  summarizeStats,
} from "discourse/plugins/live/discourse/lib/live/connection-diagnostics";

function statsReport(entries) {
  return new Map(entries.map((entry) => [entry.id, entry]));
}

const RELAYED_REPORT = statsReport([
  {
    id: "T1",
    type: "transport",
    selectedCandidatePairId: "CP1",
    dtlsState: "connected",
    iceRole: "controlling",
  },
  {
    id: "CP1",
    type: "candidate-pair",
    state: "succeeded",
    nominated: true,
    localCandidateId: "L1",
    remoteCandidateId: "R1",
    currentRoundTripTime: 0.042,
    availableOutgoingBitrate: 1_500_000,
  },
  {
    id: "CP2",
    type: "candidate-pair",
    state: "failed",
    localCandidateId: "L2",
    remoteCandidateId: "R1",
  },
  {
    id: "L1",
    type: "local-candidate",
    candidateType: "relay",
    protocol: "udp",
    relayProtocol: "tls",
    url: "turns:turn.example.com:443",
    address: "203.0.113.5",
  },
  { id: "L2", type: "local-candidate", candidateType: "host", protocol: "udp" },
  {
    id: "R1",
    type: "remote-candidate",
    candidateType: "srflx",
    protocol: "udp",
    address: "198.51.100.7",
  },
  { id: "C1", type: "codec", mimeType: "audio/opus" },
  {
    id: "IN1",
    type: "inbound-rtp",
    kind: "audio",
    codecId: "C1",
    packetsReceived: 100,
    packetsLost: 2,
  },
  { id: "IN2", type: "inbound-rtp", kind: "video", packetsReceived: 0 },
]);

module("Live | Unit | Lib | connection-diagnostics", function () {
  test("routeFor classifies the media path", function (assert) {
    assert.strictEqual(routeFor({ type: "host" }, { type: "host" }), "host");
    assert.strictEqual(routeFor({ type: "srflx" }, { type: "host" }), "stun");
    assert.strictEqual(
      routeFor({ type: "relay" }, { type: "srflx" }),
      "relay-local"
    );
    assert.strictEqual(
      routeFor({ type: "host" }, { type: "relay" }),
      "relay-remote"
    );
    assert.strictEqual(
      routeFor({ type: "relay" }, { type: "relay" }),
      "relay-both"
    );
    assert.strictEqual(routeFor(null, null), "unknown");
  });

  test("summarizeStats follows the transport's selected pair", function (assert) {
    const summary = summarizeStats(RELAYED_REPORT);

    assert.strictEqual(summary.route, "relay-local");
    assert.deepEqual(summary.selectedPair.local, {
      type: "relay",
      address: "203.0.113.5",
      port: undefined,
      protocol: "udp",
      relayProtocol: "tls",
      url: "turns:turn.example.com:443",
      networkType: undefined,
    });
    assert.strictEqual(summary.selectedPair.currentRoundTripTime, 0.042);
    assert.deepEqual(summary.candidatePairs, {
      total: 2,
      succeeded: 1,
      failed: 1,
      inProgress: 0,
    });
    assert.strictEqual(summary.localCandidates.relay, 1);
    assert.strictEqual(summary.localCandidates.host, 1);
    assert.strictEqual(summary.remoteCandidates.srflx, 1);
    assert.strictEqual(summary.transport.dtlsState, "connected");
    assert.strictEqual(summary.inbound.length, 1, "drops idle m-lines");
    assert.strictEqual(summary.inbound[0].codec, "opus");
  });

  test("summarizeStats falls back to the nominated succeeded pair", function (assert) {
    const summary = summarizeStats(
      statsReport([
        {
          id: "CP1",
          type: "candidate-pair",
          state: "succeeded",
          nominated: true,
          localCandidateId: "L1",
          remoteCandidateId: "R1",
        },
        { id: "L1", type: "local-candidate", candidateType: "host" },
        { id: "R1", type: "remote-candidate", candidateType: "host" },
      ])
    );

    assert.strictEqual(summary.route, "host");
  });

  test("summarizeStats reads the legacy ip field when address is missing", function (assert) {
    const summary = summarizeStats(
      statsReport([
        {
          id: "CP1",
          type: "candidate-pair",
          selected: true,
          localCandidateId: "L1",
          remoteCandidateId: "R1",
        },
        {
          id: "L1",
          type: "local-candidate",
          candidateType: "host",
          ip: "192.0.2.10",
          port: 50000,
        },
        { id: "R1", type: "remote-candidate", candidateType: "host" },
      ])
    );

    assert.strictEqual(summary.selectedPair.local.address, "192.0.2.10");
    assert.strictEqual(summary.selectedPair.local.port, 50000);
  });

  test("collectPeers flags expected peers that have no connection", async function (assert) {
    const pc = {
      connectionState: "connected",
      iceConnectionState: "connected",
      iceGatheringState: "complete",
      signalingState: "stable",
      getStats: async () => RELAYED_REPORT,
    };
    const peerManager = {
      get: (roomId, userId) => (userId === 2 ? pc : undefined),
      getRoomPeers: () => new Map([[2, pc]]),
      diagnosticsFor: () => ({
        restartAttempts: 0,
        maxRestartAttempts: 5,
        restartScheduled: false,
        offerRetryAttempts: 0,
        maxOfferRetries: 8,
        pendingCandidates: 0,
        iceCandidateErrors: [],
      }),
    };

    const peers = await collectPeers({
      room: {
        id: 1,
        active_participants: [
          { id: 1, username: "me" },
          { id: 2, username: "alice" },
          { id: 3, username: "bob" },
        ],
      },
      currentUserId: 1,
      peerManager,
      shouldMaintainPeer: () => true,
    });

    assert.deepEqual(
      peers.map((peer) => peer.username),
      ["alice", "bob"]
    );
    assert.strictEqual(peers[0].connection.stats.route, "relay-local");
    assert.strictEqual(peers[1].connection, null);
    assert.true(peers[1].expected);

    const report = formatReport({
      room: { id: 1, room_type: "open" },
      transport: "mesh",
      iceTransportPolicy: "all",
      local: { localTracks: [] },
      probes: [
        {
          url: "stun:stun.example.com:3478",
          reachable: false,
          timedOut: true,
          udp: true,
          candidates: {},
          relayAddresses: [],
          publicAddresses: [],
          errors: [{ errorCode: 701, errorText: "STUN timeout", count: 3 }],
        },
      ],
      peers,
      collectedAt: 0,
    });

    assert.true(report.includes("route: relay-local"));
    assert.true(report.includes("turns:turn.example.com:443"));
    assert.true(report.includes("203.0.113.5"), "includes local address");
    assert.true(report.includes("198.51.100.7"), "includes remote address");
    assert.true(report.includes("NO PEER CONNECTION (expected one)"));
    assert.true(report.includes("stun:stun.example.com:3478: NO RESPONSE"));
    assert.true(
      report.includes("\n  error: 701 STUN timeout (×3)"),
      "keeps probe errors indented and shows repeat counts"
    );
    assert.true(report.includes("public address: NONE"));
  });

  test("recordIceError folds repeated errors into a count", function (assert) {
    const errors = [];
    const timeout = {
      url: "stun:stun.example.com:3478",
      errorCode: 701,
      errorText: "STUN binding request timed out.",
    };

    recordIceError(errors, timeout);
    recordIceError(errors, timeout);
    recordIceError(errors, { ...timeout, errorCode: 1, errorText: "" });

    assert.strictEqual(errors.length, 2);
    assert.strictEqual(errors[0].count, 2);
    assert.strictEqual(errors[1].count, 1);
  });

  test("recordIceError keeps only the most recent distinct errors", function (assert) {
    const errors = [];
    for (let code = 0; code < 12; code++) {
      recordIceError(errors, { url: "turn:x", errorCode: code });
    }

    assert.strictEqual(errors.length, 10);
    assert.strictEqual(errors[0].errorCode, 2);
  });
});
