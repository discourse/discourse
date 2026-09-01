// Each remote user gets one registry-owned MediaStream that incoming mic
// audio and video tracks are merged into. Mic audio arrives with the
// sender's stream attached, but the pre-negotiated video and screen-audio
// transceivers deliver bare tracks (no stream), so keying the registry on
// incoming stream identity would make those tracks clobber the user's
// audio entry — and a bare audio track is how screen audio is told apart
// from mic audio. Screen audio lives in its own per-user stream with its
// own sink, keeping it out of the speaking detector and letting one media
// element never juggle two audio tracks.
export default class RemoteStreamRegistry {
  #streams = new Map();
  #streamToParticipant = new WeakMap();

  #onChange;
  #onMicTrack;

  constructor({ onChange, onMicTrack }) {
    this.#onChange = onChange;
    this.#onMicTrack = onMicTrack;
  }

  allStreams() {
    return Array.from(this.#streams.values())
      .filter(Array.isArray)
      .flat()
      .map((entry) => entry.stream);
  }

  allScreenAudioStreams() {
    return Array.from(this.#streams.values())
      .filter(Array.isArray)
      .flat()
      .map((entry) => entry.screenAudioStream)
      .filter(Boolean);
  }

  streamsFor(roomId) {
    return (this.#streams.get(roomId) || []).map((entry) => entry.stream);
  }

  streamFor(roomId, userId) {
    return (this.#streams.get(roomId) || []).find(
      (entry) => Number(entry?.userId) === Number(userId)
    )?.stream;
  }

  userIdsFor(roomId) {
    return (this.#streams.get(roomId) || []).map((entry) =>
      Number(entry?.userId)
    );
  }

  participantFor(stream) {
    return this.#streamToParticipant.get(stream);
  }

  register(roomId, userId, track, streams) {
    if (!roomId || !userId || !track) {
      return;
    }

    const roomStreams = this.#streams.get(roomId) || [];
    const existingIndex = roomStreams.findIndex(
      (entry) => Number(entry?.userId) === Number(userId)
    );

    let entry;
    const next = [...roomStreams];
    if (existingIndex >= 0) {
      entry = next[existingIndex];
    } else {
      entry = { userId, stream: new MediaStream() };
      next.push(entry);
    }

    const isScreenAudio = track.kind === "audio" && !streams?.length;

    if (isScreenAudio) {
      if (!entry.screenAudioStream) {
        entry.screenAudioStream = new MediaStream();
      }
      const existingTracks = entry.screenAudioStream.getTracks();
      if (!existingTracks.includes(track)) {
        existingTracks.forEach((existing) =>
          entry.screenAudioStream.removeTrack(existing)
        );
        entry.screenAudioStream.addTrack(track);
      }
      this.#streamToParticipant.set(entry.screenAudioStream, {
        roomId,
        userId,
        screenAudio: true,
      });
    } else {
      const existingTracks = entry.stream.getTracks();
      if (!existingTracks.includes(track)) {
        existingTracks
          .filter((existing) => existing.kind === track.kind)
          .forEach((existing) => entry.stream.removeTrack(existing));
        entry.stream.addTrack(track);
      }
    }

    this.#streams.set(roomId, next);
    this.#streamToParticipant.set(entry.stream, { roomId, userId });
    this.#onChange();

    if (track.kind === "audio" && !isScreenAudio) {
      this.#onMicTrack(roomId, userId, entry.stream);
    }
  }

  remove(roomId, userId) {
    if (!roomId || !userId) {
      return false;
    }

    const roomStreams = this.#streams.get(roomId);
    if (!roomStreams?.length) {
      return false;
    }

    const filtered = roomStreams.filter(
      (entry) => Number(entry?.userId) !== Number(userId)
    );

    if (filtered.length === roomStreams.length) {
      return false;
    }

    if (filtered.length) {
      this.#streams.set(roomId, filtered);
    } else {
      this.#streams.delete(roomId);
    }

    this.#onChange();
    return true;
  }

  clearRoom(roomId) {
    const entries = this.#streams.get(roomId);
    if (!entries?.length) {
      if (this.#streams.delete(roomId)) {
        this.#onChange();
      }
      return [];
    }

    this.#streams.delete(roomId);
    this.#onChange();
    return entries.map((entry) => Number(entry.userId));
  }
}
