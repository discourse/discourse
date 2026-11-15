import { module, test } from "qunit";
import {
  averageAudioLevel,
  collectPeers,
  formatDbfs,
  formatIceError,
  formatReport,
  iceErrorIsHarmless,
  parseIceUrl,
  partitionIceErrors,
  playbackProblems,
  publicIpv4Addresses,
  receivingSilence,
  recordIceError,
  routeFor,
  summarizeStats,
  unexpectedLocalAddress,
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
    assert.deepEqual(summary.pairsByType, {
      "relay→srflx": { total: 1, succeeded: 1, failed: 0, inProgress: 0 },
      "host→srflx": { total: 1, succeeded: 0, failed: 1, inProgress: 0 },
    });
    assert.deepEqual(
      summary.localCandidateSources.find((c) => c.type === "relay"),
      {
        type: "relay",
        url: "turns:turn.example.com:443",
        relayProtocol: "tls",
      }
    );
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

  test("recordIceError keeps the local addresses failing requests came from", function (assert) {
    const errors = [];
    const timeout = { url: "stun:turn.example.com:3478", errorCode: 701 };

    recordIceError(errors, { ...timeout, address: "2001:db8::5", port: 5000 });
    recordIceError(errors, { ...timeout, address: "2001:db8::5", port: 5000 });
    recordIceError(errors, { ...timeout, address: "10.0.0.2", port: 5001 });

    assert.deepEqual(errors[0].addresses, [
      "2001:db8::5:5000",
      "10.0.0.2:5001",
    ]);
    assert.strictEqual(
      formatIceError(errors[0]),
      "stun:turn.example.com:3478 701 (×3) from 2001:db8::5:5000, 10.0.0.2:5001"
    );
  });

  test("parseIceUrl normalizes endpoint defaults", function (assert) {
    assert.deepEqual(parseIceUrl("turn:turn.example.com"), {
      scheme: "turn",
      host: "turn.example.com",
      port: "3478",
      transport: "udp",
    });
    assert.deepEqual(parseIceUrl("turns:Turn.Example.com:443"), {
      scheme: "turns",
      host: "turn.example.com",
      port: "443",
      transport: "tcp",
    });
    assert.strictEqual(
      parseIceUrl("turn:turn.example.com:443?transport=tcp").transport,
      "tcp"
    );
    assert.strictEqual(parseIceUrl(undefined), null);
  });

  test("iceErrorIsHarmless when the same server produced a candidate", function (assert) {
    const candidates = [
      { type: "srflx", url: "stun:turn.example.com:3478" },
      {
        type: "relay",
        url: "turn:turn.example.com:3478?transport=udp",
        relayProtocol: "udp",
      },
    ];

    assert.true(
      iceErrorIsHarmless(
        { url: "stun:turn.example.com:3478", errorCode: 701 },
        { candidates }
      ),
      "a STUN timeout from one address while another got a public address"
    );
    assert.true(
      iceErrorIsHarmless(
        { url: "turn:turn.example.com:3478?transport=udp", errorCode: 701 },
        { candidates }
      )
    );
    assert.false(
      iceErrorIsHarmless(
        { url: "turn:turn.example.com:443?transport=tcp", errorCode: 701 },
        { candidates }
      ),
      "a different TURN endpoint was never reached"
    );
    assert.false(
      iceErrorIsHarmless(
        { url: "stun:other.example.com:3478", errorCode: 701 },
        { candidates }
      )
    );
    assert.false(iceErrorIsHarmless({ errorCode: 701 }, { candidates }));
  });

  test("iceErrorIsHarmless accepts a reachable probe of the same endpoint", function (assert) {
    const probes = [
      {
        url: "turn:turn.example.com:443?transport=tcp",
        kind: "turn",
        reachable: true,
        publicAddresses: [],
      },
      {
        url: "turn:turn.example.com:3478",
        kind: "turn",
        reachable: false,
        publicAddresses: ["198.51.100.7"],
      },
    ];

    assert.true(
      iceErrorIsHarmless(
        { url: "turn:turn.example.com:443?transport=tcp" },
        { probes }
      )
    );
    assert.true(
      iceErrorIsHarmless({ url: "stun:turn.example.com:3478" }, { probes }),
      "a public address from the TURN host answers for its STUN"
    );
    assert.false(
      iceErrorIsHarmless({ url: "turn:turn.example.com:3478" }, { probes }),
      "an unreachable TURN probe is not evidence"
    );
  });

  test("iceErrorIsHarmless needs endpoint-specific evidence when candidates lack server URLs", function (assert) {
    const candidates = [
      { type: "relay", relayProtocol: "udp" },
      { type: "srflx" },
    ];
    const probes = [
      {
        url: "turn:a.example.com:3478",
        kind: "turn",
        reachable: true,
        publicAddresses: ["198.51.100.7"],
      },
      {
        url: "turn:b.example.com:3478",
        kind: "turn",
        reachable: false,
        publicAddresses: [],
      },
    ];

    assert.false(
      iceErrorIsHarmless(
        { url: "turn:b.example.com:3478" },
        { candidates, probes }
      ),
      "a candidate that may come from working server A does not cover broken server B"
    );
    assert.false(
      iceErrorIsHarmless(
        { url: "stun:b.example.com:3478" },
        { candidates, probes }
      )
    );
    assert.true(
      iceErrorIsHarmless(
        { url: "turn:a.example.com:3478" },
        { candidates, probes }
      ),
      "server A's own probe is still evidence"
    );
  });

  test("iceErrorIsHarmless keeps TURN over TLS apart from plain TURN over TCP", function (assert) {
    const probes = [
      {
        url: "turn:turn.example.com:443?transport=tcp",
        kind: "turn",
        reachable: true,
        publicAddresses: [],
      },
      {
        url: "turns:turn.example.com:443",
        kind: "turn",
        reachable: false,
        publicAddresses: [],
      },
    ];
    const candidates = [
      {
        type: "relay",
        url: "turn:turn.example.com:443?transport=tcp",
        relayProtocol: "tcp",
      },
    ];

    assert.false(
      iceErrorIsHarmless(
        { url: "turns:turn.example.com:443?transport=tcp" },
        { probes, candidates }
      ),
      "a working plain-TCP endpoint does not cover a failing TLS one"
    );
    assert.true(
      iceErrorIsHarmless(
        { url: "turn:turn.example.com:443?transport=tcp" },
        { probes, candidates }
      )
    );
  });

  test("partitionIceErrors separates harmless errors from problems", function (assert) {
    const { problems, harmless } = partitionIceErrors(
      [
        { url: "stun:turn.example.com:3478", errorCode: 701 },
        { url: "turn:turn.example.com:3478", errorCode: 401 },
      ],
      { candidates: [{ type: "srflx", url: "stun:turn.example.com:3478" }] }
    );

    assert.deepEqual(
      problems.map((error) => error.errorCode),
      [401]
    );
    assert.deepEqual(
      harmless.map((error) => error.errorCode),
      [701]
    );
  });

  test("publicIpv4Addresses collects distinct IPv4 public addresses", function (assert) {
    assert.deepEqual(
      publicIpv4Addresses([
        { publicAddresses: ["187.10.203.159", "2804:1b3::1", "191.180.11.40"] },
        { publicAddresses: ["191.180.11.40"] },
        { publicAddresses: [] },
      ]),
      ["187.10.203.159", "191.180.11.40"]
    );
    assert.deepEqual(publicIpv4Addresses(null), []);
  });

  test("unexpectedLocalAddress flags relayed calls with a local prflx candidate", function (assert) {
    assert.true(
      unexpectedLocalAddress({
        route: "relay-local",
        localCandidates: { prflx: 1 },
      })
    );
    assert.false(
      unexpectedLocalAddress({ route: "stun", localCandidates: { prflx: 1 } }),
      "a direct connection worked despite it"
    );
    assert.false(
      unexpectedLocalAddress({
        route: "relay-local",
        localCandidates: { prflx: 0 },
      })
    );
  });

  test("formatReport labels harmless errors and multiple public addresses", function (assert) {
    const report = formatReport({
      room: { id: 1 },
      transport: "mesh",
      iceTransportPolicy: "all",
      local: { localTracks: [] },
      probes: [
        {
          url: "turn:turn.example.com:3478",
          kind: "turn",
          udp: true,
          reachable: true,
          durationMs: 100,
          candidates: {},
          relayAddresses: ["203.0.113.9"],
          publicAddresses: ["187.10.203.159", "191.180.11.40"],
          errors: [
            {
              url: "stun:turn.example.com:3478",
              errorCode: 701,
              errorText: "STUN binding request timed out.",
              count: 1,
            },
          ],
        },
      ],
      peers: [],
      collectedAt: 0,
    });

    assert.true(
      report.includes(
        "WARNING: multiple public IPv4 addresses (187.10.203.159, 191.180.11.40)"
      )
    );
    assert.true(
      report.includes(
        "  error (harmless): stun:turn.example.com:3478 701 STUN binding request timed out."
      )
    );
  });

  test("receivingSilence flags audio that arrives but decodes to silence", function (assert) {
    const silent = {
      kind: "audio",
      totalAudioEnergy: 0,
      totalSamplesDuration: 200,
    };
    const speaking = {
      kind: "audio",
      totalAudioEnergy: 0.5,
      totalSamplesDuration: 200,
    };

    assert.strictEqual(averageAudioLevel(silent), 0);
    assert.strictEqual(averageAudioLevel(speaking), Math.sqrt(0.5 / 200));
    assert.strictEqual(averageAudioLevel({ kind: "audio" }), null);
    assert.true(receivingSilence(silent));
    assert.false(receivingSilence(speaking));
    assert.false(
      receivingSilence({ ...silent, totalSamplesDuration: 2 }),
      "too little decoded to judge"
    );
    assert.false(receivingSilence({ kind: "audio" }), "no energy stats");
  });

  test("formatReport shows audio levels and playback state", async function (assert) {
    const report = statsReport([
      ...RELAYED_REPORT.values(),
      {
        id: "IN1",
        type: "inbound-rtp",
        kind: "audio",
        codecId: "C1",
        packetsReceived: 10000,
        packetsLost: 0,
        audioLevel: 0,
        totalAudioEnergy: 0,
        totalSamplesDuration: 200,
        totalSamplesReceived: 9_600_000,
        concealedSamples: 96_000,
      },
    ]);
    const pc = {
      connectionState: "connected",
      iceConnectionState: "connected",
      iceGatheringState: "complete",
      signalingState: "stable",
      getStats: async () => report,
    };

    const peers = await collectPeers({
      room: { id: 1, active_participants: [{ id: 2, username: "alice" }] },
      currentUserId: 1,
      peerManager: {
        get: () => pc,
        getRoomPeers: () => new Map([[2, pc]]),
        diagnosticsFor: () => ({ iceCandidateErrors: [] }),
      },
      shouldMaintainPeer: () => true,
      playbackFor: () => ({
        volume: 0,
        mutedByUser: false,
        deafened: false,
        elements: [
          {
            role: "live",
            paused: true,
            muted: false,
            volume: 0,
            readyState: 4,
            sinkId: "",
            tracks: [{ enabled: true, muted: false, readyState: "live" }],
          },
        ],
      }),
    });

    const text = formatReport({
      room: { id: 1 },
      transport: "mesh",
      iceTransportPolicy: "all",
      local: { localTracks: [] },
      probes: [],
      peers,
      collectedAt: 0,
    });

    assert.true(
      text.includes(
        "in audio opus: packets=10000 lost=0 jitter=? level=0.0000 avg=0.0000 decoded=200s concealed=1.0%"
      )
    );
    assert.true(
      text.includes("note: audio packets arrive but decode to silence")
    );
    assert.true(
      text.includes("playback: volume=0 muted by me=false deafened=false")
    );
    assert.true(text.includes("note: playback problems: volume_zero, paused"));
    assert.true(
      text.includes(
        "live element: paused=true muted=false volume=0 readyState=4 sink=default audio tracks=enabled/unmuted/live"
      )
    );
  });

  test("playbackProblems explains why arriving audio isn't heard", function (assert) {
    const element = {
      role: "live",
      paused: false,
      muted: false,
      volume: 1,
      tracks: [{ enabled: true, muted: false, readyState: "live" }],
    };
    const playback = (overrides = {}, elementOverrides = {}) => ({
      volume: 1,
      mutedByUser: false,
      deafened: false,
      elements: [{ ...element, ...elementOverrides }],
      ...overrides,
    });

    assert.deepEqual(playbackProblems(null), []);
    assert.deepEqual(playbackProblems(playback()), []);
    assert.deepEqual(
      playbackProblems(playback({ deafened: true }, { muted: true })),
      ["deafened"],
      "a muted element is explained by deafen"
    );
    assert.deepEqual(playbackProblems(playback({}, { muted: true })), [
      "element_muted",
    ]);
    assert.deepEqual(playbackProblems(playback({ elements: [] })), [
      "no_element",
    ]);
    assert.deepEqual(
      playbackProblems(
        playback({}, { tracks: [{ readyState: "ended" }], paused: true })
      ),
      ["paused", "track_ended"]
    );
  });

  test("formatDbfs renders linear levels on the decibel scale", function (assert) {
    assert.strictEqual(formatDbfs(1), "0 dBFS");
    assert.strictEqual(formatDbfs(0.01), "-40 dBFS");
    assert.strictEqual(formatDbfs(0), "-∞ dBFS");
    assert.strictEqual(formatDbfs(null), null);
  });
});
