// Gathers what the browser exposes about mesh peer connections so a user
// reporting "I can't hear X" can hand over something actionable. Candidate
// addresses are included because NAT/firewall triage needs them; mesh peers
// already see each other's addresses, but the report goes wider than that, so
// the UI warns before it is shared.

const PROBE_TIMEOUT_MS = 6000;

const CANDIDATE_TYPES = ["host", "srflx", "prflx", "relay"];

const MAX_ICE_ERRORS = 10;

/**
 * Records an ICE candidate error, folding repeats into a count: browsers retry
 * each server per interface and transaction, so the same failure otherwise
 * floods the list and pushes out the distinct ones.
 *
 * @param {Array<object>} errors - Mutated in place.
 * @param {{url?: string, errorCode?: number, errorText?: string}} error
 */
export function recordIceError(errors, { url, errorCode, errorText }) {
  const existing = errors.find(
    (entry) =>
      entry.url === url &&
      entry.errorCode === errorCode &&
      entry.errorText === errorText
  );
  if (existing) {
    existing.count++;
    existing.lastAt = Date.now();
    return errors;
  }

  errors.push({ url, errorCode, errorText, count: 1, lastAt: Date.now() });
  if (errors.length > MAX_ICE_ERRORS) {
    errors.shift();
  }
  return errors;
}

/**
 * @param {{url?: string, errorCode?: number, errorText?: string, count?: number}} error
 * @param {{includeUrl?: boolean}} [options]
 */
export function formatIceError(error, { includeUrl = true } = {}) {
  const text = [
    includeUrl && error.url,
    error.errorCode,
    error.errorText,
    error.count > 1 && `(×${error.count})`,
  ]
    .filter(Boolean)
    .join(" ");
  return text || "?";
}

function statsValues(report) {
  if (!report) {
    return [];
  }
  return typeof report.values === "function"
    ? Array.from(report.values())
    : Object.values(report);
}

function emptyCandidateCounts() {
  return Object.fromEntries(CANDIDATE_TYPES.map((type) => [type, 0]));
}

function candidateSummary(stat) {
  if (!stat) {
    return null;
  }
  return {
    type: stat.candidateType,
    // Older Chromium reports `ip` instead of `address`.
    address: stat.address ?? stat.ip,
    port: stat.port,
    protocol: stat.protocol,
    relayProtocol: stat.relayProtocol,
    url: stat.url,
    networkType: stat.networkType,
  };
}

function selectedPairFrom(stats, byId) {
  for (const stat of stats) {
    if (stat.type === "transport" && stat.selectedCandidatePairId) {
      const pair = byId.get(stat.selectedCandidatePairId);
      if (pair) {
        return pair;
      }
    }
  }

  const pairs = stats.filter((stat) => stat.type === "candidate-pair");
  return (
    pairs.find((pair) => pair.selected) ??
    pairs.find((pair) => pair.nominated && pair.state === "succeeded")
  );
}

/**
 * Classifies how media flows between us and a peer.
 *
 * @param {{type?: string}|null} local
 * @param {{type?: string}|null} remote
 * @returns {"relay-both"|"relay-local"|"relay-remote"|"stun"|"host"|"unknown"}
 */
export function routeFor(local, remote) {
  const localRelay = local?.type === "relay";
  const remoteRelay = remote?.type === "relay";

  if (localRelay && remoteRelay) {
    return "relay-both";
  }
  if (localRelay) {
    return "relay-local";
  }
  if (remoteRelay) {
    return "relay-remote";
  }
  if (!local?.type || !remote?.type) {
    return "unknown";
  }
  if (local.type === "host" && remote.type === "host") {
    return "host";
  }
  return "stun";
}

/**
 * Reduces an RTCStatsReport to the fields useful for connection triage.
 *
 * @param {RTCStatsReport|Map<string, object>} report
 */
export function summarizeStats(report) {
  const stats = statsValues(report);
  const byId = new Map(stats.map((stat) => [stat.id, stat]));

  const pair = selectedPairFrom(stats, byId);
  const local = candidateSummary(byId.get(pair?.localCandidateId));
  const remote = candidateSummary(byId.get(pair?.remoteCandidateId));

  const localCandidates = emptyCandidateCounts();
  const remoteCandidates = emptyCandidateCounts();
  const candidatePairs = { total: 0, succeeded: 0, failed: 0, inProgress: 0 };
  const inbound = [];
  const outbound = [];
  let transport = null;

  const codecName = (id) => byId.get(id)?.mimeType?.split("/")[1];

  for (const stat of stats) {
    switch (stat.type) {
      case "local-candidate":
        if (stat.candidateType in localCandidates) {
          localCandidates[stat.candidateType]++;
        }
        break;
      case "remote-candidate":
        if (stat.candidateType in remoteCandidates) {
          remoteCandidates[stat.candidateType]++;
        }
        break;
      case "candidate-pair":
        candidatePairs.total++;
        if (stat.state === "succeeded") {
          candidatePairs.succeeded++;
        } else if (stat.state === "failed") {
          candidatePairs.failed++;
        } else if (stat.state === "in-progress") {
          candidatePairs.inProgress++;
        }
        break;
      case "transport":
        transport ??= {
          dtlsState: stat.dtlsState,
          iceState: stat.iceState,
          iceRole: stat.iceRole,
          tlsVersion: stat.tlsVersion,
          srtpCipher: stat.srtpCipher,
        };
        break;
      case "inbound-rtp":
        inbound.push({
          kind: stat.kind,
          codec: codecName(stat.codecId),
          packetsReceived: stat.packetsReceived,
          packetsLost: stat.packetsLost,
          jitter: stat.jitter,
          bytesReceived: stat.bytesReceived,
          framesPerSecond: stat.framesPerSecond,
          frameWidth: stat.frameWidth,
          frameHeight: stat.frameHeight,
        });
        break;
      case "outbound-rtp":
        outbound.push({
          kind: stat.kind,
          codec: codecName(stat.codecId),
          packetsSent: stat.packetsSent,
          bytesSent: stat.bytesSent,
          framesPerSecond: stat.framesPerSecond,
          frameWidth: stat.frameWidth,
          frameHeight: stat.frameHeight,
          qualityLimitationReason: stat.qualityLimitationReason,
        });
        break;
    }
  }

  return {
    route: routeFor(local, remote),
    selectedPair: pair
      ? {
          local,
          remote,
          state: pair.state,
          currentRoundTripTime: pair.currentRoundTripTime,
          availableOutgoingBitrate: pair.availableOutgoingBitrate,
          availableIncomingBitrate: pair.availableIncomingBitrate,
          bytesSent: pair.bytesSent,
          bytesReceived: pair.bytesReceived,
        }
      : null,
    localCandidates,
    remoteCandidates,
    candidatePairs,
    transport,
    // Pre-negotiated idle m-lines report zero-packet RTP entries; they are
    // noise when nothing is being sent on them.
    inbound: inbound.filter((entry) => entry.packetsReceived > 0),
    outbound: outbound.filter((entry) => entry.packetsSent > 0),
  };
}

/**
 * Collects state and stats for one peer connection.
 *
 * @param {RTCPeerConnection} pc
 */
export async function collectPeerConnection(pc) {
  const states = {
    connectionState: pc.connectionState,
    iceConnectionState: pc.iceConnectionState,
    iceGatheringState: pc.iceGatheringState,
    signalingState: pc.signalingState,
  };

  try {
    return { ...states, stats: summarizeStats(await pc.getStats()) };
  } catch (error) {
    return { ...states, stats: null, statsError: String(error?.message) };
  }
}

/**
 * Details about this browser and network the WebRTC stack doesn't report.
 *
 * @param {MediaStream|null} localStream
 */
export function collectLocalInfo(localStream) {
  const nav = globalThis.navigator || {};
  const connection = nav.connection;

  return {
    userAgent: nav.userAgent,
    platform: nav.userAgentData?.platform || nav.platform,
    online: nav.onLine,
    secureContext: globalThis.isSecureContext,
    hardwareConcurrency: nav.hardwareConcurrency,
    deviceMemory: nav.deviceMemory,
    connection: connection
      ? {
          type: connection.type,
          effectiveType: connection.effectiveType,
          downlink: connection.downlink,
          rtt: connection.rtt,
          saveData: connection.saveData,
        }
      : null,
    localTracks: (localStream?.getTracks() || []).map((track) => ({
      kind: track.kind,
      label: track.label,
      enabled: track.enabled,
      muted: track.muted,
      readyState: track.readyState,
    })),
  };
}

function iceServerUrls(iceServers) {
  const entries = [];
  for (const server of iceServers || []) {
    const urls = Array.isArray(server.urls) ? server.urls : [server.urls];
    for (const url of urls.filter(Boolean)) {
      entries.push({ url, server });
    }
  }
  return entries;
}

/**
 * Checks one STUN/TURN URL in isolation: a throwaway connection gathers
 * candidates against only that server, so a srflx (STUN) or relay (TURN)
 * candidate proves this browser can reach and authenticate with it.
 *
 * @param {string} url
 * @param {RTCIceServer} server
 * @param {{timeoutMs?: number}} [options]
 */
export async function probeIceServer(url, server, options = {}) {
  const timeoutMs = options.timeoutMs ?? PROBE_TIMEOUT_MS;
  const isTurn = /^turns?:/i.test(url);
  const expectedType = isTurn ? "relay" : "srflx";
  // Browsers only learn their public address over UDP; a TCP/TLS server
  // never yields one, so its absence there says nothing.
  const udp = !/^turns:/i.test(url) && !/[?&]transport=tcp/i.test(url);
  const startedAt = performance.now();

  const result = {
    url,
    kind: isTurn ? "turn" : "stun",
    reachable: false,
    udp,
    candidates: emptyCandidateCounts(),
    relayAddresses: [],
    // Our NAT's public address as the server saw it. Missing over UDP means
    // direct (non-relayed) connections can't be set up through this network.
    publicAddresses: [],
    errors: [],
    timedOut: false,
    durationMs: null,
  };

  let pc;
  try {
    pc = new RTCPeerConnection({
      iceServers: [
        {
          urls: url,
          username: server.username,
          credential: server.credential,
        },
      ],
    });
  } catch (error) {
    result.errors.push({ errorText: String(error?.message) });
    return result;
  }

  try {
    await new Promise((resolve) => {
      const timer = setTimeout(() => {
        result.timedOut = true;
        resolve();
      }, timeoutMs);

      pc.onicecandidate = (event) => {
        const type = event.candidate?.type;
        if (type && type in result.candidates) {
          result.candidates[type]++;
          const address = event.candidate.address;
          const addresses =
            type === "relay"
              ? result.relayAddresses
              : type === "srflx"
                ? result.publicAddresses
                : null;
          if (addresses && address && !addresses.includes(address)) {
            addresses.push(address);
          }
          if (type === expectedType && !result.reachable) {
            result.reachable = true;
            result.durationMs = Math.round(performance.now() - startedAt);
          }
        }
        if (!event.candidate) {
          clearTimeout(timer);
          resolve();
        }
      };
      pc.onicecandidateerror = (event) => {
        recordIceError(result.errors, {
          url: event.url,
          errorCode: event.errorCode,
          errorText: event.errorText,
        });
      };

      pc.createDataChannel("diagnostics");
      pc.createOffer()
        .then((offer) => pc.setLocalDescription(offer))
        .catch((error) => {
          result.errors.push({ errorText: String(error?.message) });
          clearTimeout(timer);
          resolve();
        });
    });
  } finally {
    pc.onicecandidate = null;
    pc.onicecandidateerror = null;
    pc.close();
  }

  return result;
}

/**
 * Probes every configured STUN/TURN URL in parallel.
 *
 * @param {RTCIceServer[]} iceServers
 * @param {{timeoutMs?: number}} [options]
 */
export function probeIceServers(iceServers, options = {}) {
  return Promise.all(
    iceServerUrls(iceServers).map(({ url, server }) =>
      probeIceServer(url, server, options)
    )
  );
}

/**
 * Builds per-participant diagnostics for a mesh room.
 *
 * @param {object} params
 * @param {object} params.room - Room with `active_participants`.
 * @param {number} params.currentUserId
 * @param {import("./peer-manager.js").default} params.peerManager
 * @param {(userId: number) => boolean} params.shouldMaintainPeer
 */
export async function collectPeers({
  room,
  currentUserId,
  peerManager,
  shouldMaintainPeer,
}) {
  const participants = new Map();
  for (const participant of room?.active_participants || []) {
    const id = Number(participant?.id);
    if (id > 0 && id !== currentUserId) {
      participants.set(id, participant);
    }
  }

  // A connection to someone no longer in the roster is itself a symptom.
  for (const [userId] of peerManager.getRoomPeers(room?.id) || []) {
    if (!participants.has(Number(userId))) {
      participants.set(Number(userId), { id: userId });
    }
  }

  return Promise.all(
    Array.from(participants.values()).map(async (participant) => {
      const userId = Number(participant.id);
      const pc = peerManager.get(room.id, userId);
      return {
        userId,
        username: participant.username,
        name: participant.name,
        avatarTemplate: participant.avatar_template,
        inRoster: !!participant.username,
        expected: shouldMaintainPeer(userId),
        recovery: peerManager.diagnosticsFor(room.id, userId),
        connection: pc ? await collectPeerConnection(pc) : null,
      };
    })
  );
}

export function formatBitrate(bps) {
  if (typeof bps !== "number") {
    return "?";
  }
  return bps >= 1e6
    ? `${(bps / 1e6).toFixed(2)} Mbps`
    : `${Math.round(bps / 1e3)} kbps`;
}

export function formatRtt(seconds) {
  return typeof seconds === "number" ? `${Math.round(seconds * 1000)} ms` : "?";
}

function formatCandidate(candidate) {
  if (!candidate) {
    return "?";
  }
  return [
    candidate.address &&
      (candidate.port
        ? `${candidate.address}:${candidate.port}`
        : candidate.address),
    candidate.type,
    candidate.protocol,
    candidate.relayProtocol && `relay over ${candidate.relayProtocol}`,
    candidate.networkType,
    candidate.url,
  ]
    .filter(Boolean)
    .join(" / ");
}

export function formatCandidateCounts(counts) {
  return CANDIDATE_TYPES.map((type) => `${type}=${counts?.[type] ?? 0}`).join(
    " "
  );
}

/**
 * Renders collected diagnostics as plain text for copying into a bug report.
 * Intentionally untranslated so reports read the same for whoever triages.
 */
export function formatReport({
  room,
  transport,
  iceTransportPolicy,
  local,
  probes,
  peers,
  collectedAt,
}) {
  const lines = [];
  const push = (line = "") => lines.push(line);

  push("Live connection diagnostics");
  push(`Collected: ${new Date(collectedAt).toISOString()}`);
  push(`Room: ${room?.id} (${transport}, ${room?.room_type || "open"})`);
  push(`ICE transport policy: ${iceTransportPolicy}`);
  push();

  push("== This device ==");
  push(`User agent: ${local.userAgent}`);
  push(`Platform: ${local.platform}`);
  push(`Online: ${local.online}  Secure context: ${local.secureContext}`);
  push(
    `CPU cores: ${local.hardwareConcurrency ?? "?"}  Memory: ${local.deviceMemory ?? "?"} GB`
  );
  if (local.connection) {
    const c = local.connection;
    push(
      `Network: type=${c.type ?? "?"} effective=${c.effectiveType ?? "?"} downlink=${c.downlink ?? "?"}Mbps rtt=${c.rtt ?? "?"}ms saveData=${c.saveData ?? "?"}`
    );
  }
  for (const track of local.localTracks) {
    push(
      `Local ${track.kind}: "${track.label}" enabled=${track.enabled} muted=${track.muted} state=${track.readyState}`
    );
  }
  push();

  push("== STUN/TURN servers ==");
  if (!probes) {
    push("(probe not run)");
  } else if (!probes.length) {
    push("(none configured)");
  }
  for (const probe of probes || []) {
    const status = probe.reachable
      ? `OK in ${probe.durationMs} ms`
      : probe.timedOut
        ? "NO RESPONSE (timed out)"
        : "FAILED";
    push(`${probe.url}: ${status}`);
    push(`  candidates: ${formatCandidateCounts(probe.candidates)}`);
    if (probe.relayAddresses?.length) {
      push(`  relay address: ${probe.relayAddresses.join(", ")}`);
    }
    if (probe.publicAddresses?.length) {
      push(`  public address: ${probe.publicAddresses.join(", ")}`);
    } else if (probe.udp) {
      push("  public address: NONE (STUN binding got no answer)");
    }
    for (const error of probe.errors) {
      push(`  error: ${formatIceError(error)}`);
    }
  }
  push();

  push(`== Peers (${peers.length}) ==`);
  for (const peer of peers) {
    push(
      `-- ${peer.username || `user ${peer.userId}`} (id ${peer.userId})${peer.inRoster ? "" : " [not in roster]"}`
    );
    const recovery = peer.recovery;
    push(
      `  restarts: ${recovery.restartAttempts}/${recovery.maxRestartAttempts}${recovery.restartScheduled ? " (restart pending)" : ""}  offer retries: ${recovery.offerRetryAttempts}/${recovery.maxOfferRetries}  queued candidates: ${recovery.pendingCandidates}`
    );
    for (const error of recovery.iceCandidateErrors) {
      push(`  ICE error: ${formatIceError(error)}`);
    }

    const connection = peer.connection;
    if (!connection) {
      push(
        peer.expected
          ? "  NO PEER CONNECTION (expected one)"
          : "  no peer connection (not expected in this room)"
      );
      continue;
    }

    push(
      `  state: connection=${connection.connectionState} ice=${connection.iceConnectionState} gathering=${connection.iceGatheringState} signaling=${connection.signalingState}`
    );
    const stats = connection.stats;
    if (!stats) {
      push(`  stats unavailable: ${connection.statsError}`);
      continue;
    }
    push(`  route: ${stats.route}`);
    if (stats.selectedPair) {
      const pair = stats.selectedPair;
      push(`  local candidate: ${formatCandidate(pair.local)}`);
      push(`  remote candidate: ${formatCandidate(pair.remote)}`);
      push(
        `  rtt: ${formatRtt(pair.currentRoundTripTime)}  out bitrate: ${formatBitrate(pair.availableOutgoingBitrate)}  sent: ${pair.bytesSent ?? "?"} B  received: ${pair.bytesReceived ?? "?"} B`
      );
    } else {
      push("  no selected candidate pair");
    }
    push(
      `  candidate pairs: total=${stats.candidatePairs.total} succeeded=${stats.candidatePairs.succeeded} failed=${stats.candidatePairs.failed} in-progress=${stats.candidatePairs.inProgress}`
    );
    push(`  local candidates: ${formatCandidateCounts(stats.localCandidates)}`);
    push(
      `  remote candidates: ${formatCandidateCounts(stats.remoteCandidates)}`
    );
    if (stats.transport) {
      const t = stats.transport;
      push(
        `  dtls: ${t.dtlsState ?? "?"}  ice role: ${t.iceRole ?? "?"}  tls: ${t.tlsVersion ?? "?"}  srtp: ${t.srtpCipher ?? "?"}`
      );
    }
    for (const entry of stats.inbound) {
      push(
        `  in ${entry.kind} ${entry.codec ?? ""}: packets=${entry.packetsReceived} lost=${entry.packetsLost ?? "?"} jitter=${entry.jitter ?? "?"}${entry.frameWidth ? ` ${entry.frameWidth}x${entry.frameHeight}@${entry.framesPerSecond ?? "?"}` : ""}`
      );
    }
    for (const entry of stats.outbound) {
      push(
        `  out ${entry.kind} ${entry.codec ?? ""}: packets=${entry.packetsSent}${entry.qualityLimitationReason ? ` limited=${entry.qualityLimitationReason}` : ""}${entry.frameWidth ? ` ${entry.frameWidth}x${entry.frameHeight}@${entry.framesPerSecond ?? "?"}` : ""}`
      );
    }
  }

  return lines.join("\n");
}
