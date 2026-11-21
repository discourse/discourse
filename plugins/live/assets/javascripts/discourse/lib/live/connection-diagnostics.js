// Gathers what the browser exposes about mesh peer connections so a user
// reporting "I can't hear X" can hand over something actionable. Candidate
// addresses are included because NAT/firewall triage needs them; mesh peers
// already see each other's addresses, but the report goes wider than that, so
// the UI warns before it is shared.

const PROBE_TIMEOUT_MS = 6000;

const CANDIDATE_TYPES = ["host", "srflx", "prflx", "relay"];

const MAX_ICE_ERRORS = 10;
const MAX_ERROR_ADDRESSES = 4;

/**
 * Records an ICE candidate error, folding repeats into a count: browsers retry
 * each server per interface and transaction, so the same failure otherwise
 * floods the list and pushes out the distinct ones. The local addresses the
 * failing requests were sent from are kept, since they tell which interface
 * or address family can't reach the server.
 *
 * @param {Array<object>} errors - Mutated in place.
 * @param {{url?: string, errorCode?: number, errorText?: string, address?: string, port?: number}} error
 */
export function recordIceError(
  errors,
  { url, errorCode, errorText, address, port }
) {
  let entry = errors.find(
    (existing) =>
      existing.url === url &&
      existing.errorCode === errorCode &&
      existing.errorText === errorText
  );
  if (entry) {
    entry.count++;
    entry.lastAt = Date.now();
  } else {
    entry = {
      url,
      errorCode,
      errorText,
      addresses: [],
      count: 1,
      lastAt: Date.now(),
    };
    errors.push(entry);
    if (errors.length > MAX_ICE_ERRORS) {
      errors.shift();
    }
  }

  const source = address && (port ? `${address}:${port}` : address);
  if (
    source &&
    !entry.addresses.includes(source) &&
    entry.addresses.length < MAX_ERROR_ADDRESSES
  ) {
    entry.addresses.push(source);
  }
  return errors;
}

/**
 * @param {{url?: string, errorCode?: number, errorText?: string, count?: number, addresses?: string[]}} error
 * @param {{includeUrl?: boolean}} [options]
 */
export function formatIceError(error, { includeUrl = true } = {}) {
  const text = [
    includeUrl && error.url,
    error.errorCode,
    error.errorText,
    error.count > 1 && `(×${error.count})`,
    error.addresses?.length && `from ${error.addresses.join(", ")}`,
  ]
    .filter(Boolean)
    .join(" ");
  return text || "?";
}

/**
 * Splits an ICE server URL into the parts that identify an endpoint.
 *
 * @param {string} url
 * @returns {{scheme: string, host: string, port: string, transport: string}|null}
 */
export function parseIceUrl(url) {
  const match = /^(stuns?|turns?):([^?]+?)(?::(\d+))?(?:\?(.*))?$/i.exec(
    url || ""
  );
  if (!match) {
    return null;
  }

  const scheme = match[1].toLowerCase();
  const secure = scheme.endsWith("s");
  return {
    scheme,
    host: match[2].toLowerCase(),
    port: match[3] ?? (secure ? "5349" : "3478"),
    transport:
      new URLSearchParams(match[4] || "").get("transport")?.toLowerCase() ??
      (secure ? "tcp" : "udp"),
  };
}

function sameHost(a, b) {
  return a && b && a.host === b.host && a.port === b.port;
}

// TURN over TLS and plain TURN over TCP can share a host and port, yet one
// working says nothing about the other (e.g. a certificate problem).
function sameRelayEndpoint(a, b) {
  return sameHost(a, b) && a.scheme === b.scheme && a.transport === b.transport;
}

/**
 * Whether the server an ICE error is about was reached anyway. Browsers try
 * every server from every local address and interface, so one address failing
 * (an IPv6 address without a route, a VPN or container interface) is expected
 * noise as long as another address got the answer the error was waiting for.
 *
 * @param {{url?: string}} error
 * @param {object} evidence
 * @param {Array<{type: string, url?: string, relayProtocol?: string}>} [evidence.candidates] - Local candidates gathered on the same connection.
 * @param {Array<object>} [evidence.probes] - STUN/TURN server probe results.
 */
export function iceErrorIsHarmless(error, { candidates = [], probes = [] }) {
  const target = parseIceUrl(error.url);
  if (!target) {
    return false;
  }
  const wantsRelay = target.scheme.startsWith("turn");

  const probed = probes.some((probe) => {
    const endpoint = parseIceUrl(probe.url);
    return wantsRelay
      ? probe.reachable && sameRelayEndpoint(endpoint, target)
      : sameHost(endpoint, target) && probe.publicAddresses?.length > 0;
  });
  if (probed) {
    return true;
  }

  return candidates.some((candidate) => {
    if (candidate.type !== (wantsRelay ? "relay" : "srflx")) {
      return false;
    }
    // Not every browser reports which server produced a candidate. Without
    // that, the candidate may come from a different, working server, so it
    // is no evidence for this one; the probes still are.
    const source = parseIceUrl(candidate.url);
    if (!source) {
      return false;
    }
    return wantsRelay
      ? sameRelayEndpoint(source, target)
      : sameHost(source, target);
  });
}

/**
 * @param {Array<object>} errors
 * @param {Parameters<typeof iceErrorIsHarmless>[1]} evidence
 * @returns {{problems: Array<object>, harmless: Array<object>}}
 */
export function partitionIceErrors(errors, evidence) {
  const problems = [];
  const harmless = [];
  for (const error of errors || []) {
    (iceErrorIsHarmless(error, evidence) ? harmless : problems).push(error);
  }
  return { problems, harmless };
}

/**
 * Distinct public IPv4 addresses the STUN/TURN servers saw this device as.
 * More than one usually means traffic leaves through several internet
 * connections, which makes the public address a peer is told about
 * unreliable. IPv6 is excluded: one IPv6 address per interface is normal.
 *
 * @param {Array<object>|null} probes
 */
export function publicIpv4Addresses(probes) {
  const addresses = new Set();
  for (const probe of probes || []) {
    for (const address of probe.publicAddresses || []) {
      if (!address.includes(":")) {
        addresses.add(address);
      }
    }
  }
  return Array.from(addresses);
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
  const pairsByType = {};
  const localCandidateSources = [];
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
        localCandidateSources.push({
          type: stat.candidateType,
          url: stat.url,
          relayProtocol: stat.relayProtocol,
        });
        break;
      case "remote-candidate":
        if (stat.candidateType in remoteCandidates) {
          remoteCandidates[stat.candidateType]++;
        }
        break;
      case "candidate-pair": {
        const key = `${byId.get(stat.localCandidateId)?.candidateType ?? "?"}→${byId.get(stat.remoteCandidateId)?.candidateType ?? "?"}`;
        pairsByType[key] ??= {
          total: 0,
          succeeded: 0,
          failed: 0,
          inProgress: 0,
        };
        for (const counts of [candidatePairs, pairsByType[key]]) {
          counts.total++;
          if (stat.state === "succeeded") {
            counts.succeeded++;
          } else if (stat.state === "failed") {
            counts.failed++;
          } else if (stat.state === "in-progress") {
            counts.inProgress++;
          }
        }
        break;
      }
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
          audioLevel: stat.audioLevel,
          totalAudioEnergy: stat.totalAudioEnergy,
          totalSamplesDuration: stat.totalSamplesDuration,
          totalSamplesReceived: stat.totalSamplesReceived,
          concealedSamples: stat.concealedSamples,
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
    pairsByType,
    localCandidateSources,
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
          address: event.address,
          port: event.port,
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
 * @param {(userId: number) => object|null} [params.playbackFor] - How this
 *   device plays the peer's audio; see `ParticipantAudio#playbackFor`.
 */
export async function collectPeers({
  room,
  currentUserId,
  peerManager,
  shouldMaintainPeer,
  playbackFor,
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
        playback: playbackFor?.(userId) ?? null,
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

/**
 * @param {Record<string, {total: number, succeeded: number, failed: number, inProgress: number}>} pairsByType
 */
export function formatPairsByType(pairsByType) {
  return Object.entries(pairsByType || {})
    .map(
      ([types, counts]) =>
        `${types} ${counts.succeeded}ok/${counts.failed}failed/${counts.total}`
    )
    .join(", ");
}

/**
 * A local peer-reflexive candidate means the peer saw our packets come from a
 * public address none of the STUN servers reported, i.e. traffic to this peer
 * took a different NAT mapping or internet connection. When the call then
 * ends up relayed, that mismatch is the likely reason direct paths failed.
 */
export function unexpectedLocalAddress(stats) {
  return stats?.localCandidates?.prflx > 0 && stats.route.startsWith("relay");
}

// Decoded audio quieter than this (linear RMS) is digital silence rather than
// a live microphone, whose noise floor sits well above it.
const SILENT_AUDIO_RMS = 0.0005;

/**
 * Root-mean-square level of everything decoded so far, from the cumulative
 * energy the stats report keeps; unlike `audioLevel` it doesn't depend on
 * whether the peer happened to be speaking when the report was collected.
 *
 * @param {{totalAudioEnergy?: number, totalSamplesDuration?: number}} entry
 * @returns {number|null}
 */
export function averageAudioLevel(entry) {
  if (
    typeof entry?.totalAudioEnergy !== "number" ||
    !(entry.totalSamplesDuration > 0)
  ) {
    return null;
  }
  return Math.sqrt(entry.totalAudioEnergy / entry.totalSamplesDuration);
}

/**
 * Whether audio packets arrive but decode to silence, which puts the problem
 * on the sender's side (muted or wrong input device) rather than the network
 * or this device's playback.
 */
export function receivingSilence(entry) {
  const level = averageAudioLevel(entry);
  return (
    entry?.kind === "audio" &&
    entry.totalSamplesDuration > 5 &&
    level !== null &&
    level < SILENT_AUDIO_RMS
  );
}

/**
 * Formats a linear audio level as dBFS, the scale audio tools use.
 *
 * @param {number|null} level
 * @returns {string|null}
 */
export function formatDbfs(level) {
  if (typeof level !== "number") {
    return null;
  }
  return level > 0 ? `${Math.round(20 * Math.log10(level))} dBFS` : "-∞ dBFS";
}

/**
 * The main inbound audio stream for a peer: screen-share audio can add a
 * second one, and the microphone is the one that carries the most packets.
 */
export function primaryInboundAudio(stats) {
  return (stats?.inbound || [])
    .filter((entry) => entry.kind === "audio")
    .sort((a, b) => b.packetsReceived - a.packetsReceived)[0];
}

/**
 * Reasons this device wouldn't play a peer's audio even when it arrives.
 *
 * @param {object|null} playback - From `ParticipantAudio#playbackFor`.
 * @returns {string[]} Keys under `live.connection_diagnostics.playback_problems`.
 */
export function playbackProblems(playback) {
  if (!playback) {
    return [];
  }

  const problems = [];
  if (playback.deafened) {
    problems.push("deafened");
  }
  if (playback.mutedByUser) {
    problems.push("muted_by_you");
  }
  if (playback.volume === 0) {
    problems.push("volume_zero");
  }

  const element = playback.elements.find(({ role }) => role === "live");
  if (!element) {
    problems.push("no_element");
    return problems;
  }
  if (element.paused) {
    problems.push("paused");
  }
  // Deafen and per-peer mute are applied by muting the element.
  if (element.muted && !playback.deafened && !playback.mutedByUser) {
    problems.push("element_muted");
  }
  if (!element.tracks.length) {
    problems.push("no_track");
  } else if (element.tracks.every((track) => track.readyState === "ended")) {
    problems.push("track_ended");
  }
  return problems;
}

function formatLevel(value) {
  return typeof value === "number" ? value.toFixed(4) : "?";
}

function formatAudioLevels(entry) {
  if (entry.kind !== "audio" || entry.totalSamplesDuration === undefined) {
    return "";
  }
  const concealed =
    entry.totalSamplesReceived > 0 && entry.concealedSamples !== undefined
      ? `${((entry.concealedSamples / entry.totalSamplesReceived) * 100).toFixed(1)}%`
      : "?";
  return ` level=${formatLevel(entry.audioLevel)} avg=${formatLevel(averageAudioLevel(entry))} decoded=${Math.round(entry.totalSamplesDuration)}s concealed=${concealed}`;
}

function formatPlayback(playback) {
  const lines = [];
  lines.push(
    `  playback: volume=${playback.volume} muted by me=${playback.mutedByUser} deafened=${playback.deafened}`
  );
  const problems = playbackProblems(playback);
  if (problems.length) {
    lines.push(`  note: playback problems: ${problems.join(", ")}`);
  }
  for (const element of playback.elements) {
    const tracks = element.tracks.length
      ? element.tracks
          .map(
            (track) =>
              `${track.enabled ? "enabled" : "disabled"}/${track.muted ? "muted" : "unmuted"}/${track.readyState}`
          )
          .join(", ")
      : "none";
    lines.push(
      `  ${element.role} element: paused=${element.paused} muted=${element.muted} volume=${element.volume} readyState=${element.readyState} sink=${element.sinkId || "default"} audio tracks=${tracks}`
    );
  }
  return lines;
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
  const publicIpv4 = publicIpv4Addresses(probes);
  if (publicIpv4.length > 1) {
    push(
      `WARNING: multiple public IPv4 addresses (${publicIpv4.join(", ")}); traffic may leave through more than one internet connection`
    );
  }
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
    const probeErrors = partitionIceErrors(probe.errors, {
      probes: probes || [],
    });
    for (const error of probeErrors.problems) {
      push(`  error: ${formatIceError(error)}`);
    }
    for (const error of probeErrors.harmless) {
      push(`  error (harmless): ${formatIceError(error)}`);
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
    const peerErrors = partitionIceErrors(recovery.iceCandidateErrors, {
      candidates: peer.connection?.stats?.localCandidateSources,
      probes: probes || [],
    });
    for (const error of peerErrors.problems) {
      push(`  ICE error: ${formatIceError(error)}`);
    }
    for (const error of peerErrors.harmless) {
      push(`  ICE error (harmless, server reached): ${formatIceError(error)}`);
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

    if (peer.playback) {
      formatPlayback(peer.playback).forEach((line) => push(line));
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
    const pairTypes = formatPairsByType(stats.pairsByType);
    if (pairTypes) {
      push(`  pairs by type: ${pairTypes}`);
    }
    if (unexpectedLocalAddress(stats)) {
      push(
        "  note: traffic to this peer left from a public address no STUN server reported (local prflx); direct paths likely failed because of it"
      );
    }
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
        `  in ${entry.kind} ${entry.codec ?? ""}: packets=${entry.packetsReceived} lost=${entry.packetsLost ?? "?"} jitter=${entry.jitter ?? "?"}${formatAudioLevels(entry)}${entry.frameWidth ? ` ${entry.frameWidth}x${entry.frameHeight}@${entry.framesPerSecond ?? "?"}` : ""}`
      );
      if (receivingSilence(entry)) {
        push(
          "  note: audio packets arrive but decode to silence; the sender's microphone is likely muted or the wrong input device"
        );
      }
    }
    for (const entry of stats.outbound) {
      push(
        `  out ${entry.kind} ${entry.codec ?? ""}: packets=${entry.packetsSent}${entry.qualityLimitationReason ? ` limited=${entry.qualityLimitationReason}` : ""}${entry.frameWidth ? ` ${entry.frameWidth}x${entry.frameHeight}@${entry.framesPerSecond ?? "?"}` : ""}`
      );
    }
  }

  return lines.join("\n");
}
