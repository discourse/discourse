/**
 * Convert track direction to content placement.
 * Per Silk's logic: when only tracks is provided, contentPlacement = tracks.
 * Array tracks and horizontal/vertical normalize to "center".
 *
 * @param {string|Array<string>} track - Track direction or array of tracks
 * @returns {string} Content placement value
 */
export function trackToPlacement(track) {
  if (Array.isArray(track)) {
    return "center";
  }
  switch (track) {
    case "horizontal":
    case "vertical":
      return "center";
    default:
      return track; // "top", "bottom", "left", "right"
  }
}

/**
 * Normalize array tracks to a single track string.
 * Array tracks like ["left", "right"] or ["top", "bottom"] are normalized
 * to "horizontal" or "vertical" respectively.
 *
 * @param {string|Array<string>} track - Track direction or array of tracks
 * @returns {string} Normalized track value
 */
export function normalizeTrack(track) {
  if (Array.isArray(track)) {
    return track.includes("left") ? "horizontal" : "vertical";
  }
  return track;
}

/**
 * Convert API placement value to CSS class.
 * The CSS uses "start", "end", "center" internally.
 *
 * @param {string} placement - Placement value ("top" | "bottom" | "left" | "right" | "center")
 * @returns {string} CSS class value ("start" | "end" | "center")
 */
export function placementToCssClass(placement) {
  switch (placement) {
    case "top":
    case "left":
      return "start";
    case "bottom":
    case "right":
      return "end";
    case "center":
      return "center";
    default:
      return "end";
  }
}

/**
 * Get the default track value when contentPlacement is "center" but no tracks is provided.
 *
 * @param {string} contentPlacement - The content placement value
 * @param {string|Array<string>|undefined} tracks - The tracks value (if any)
 * @returns {string} The default track value
 */
export function getDefaultTrackForPlacement(contentPlacement, tracks) {
  if (contentPlacement === "center" && !tracks) {
    return "bottom";
  }
  return tracks || "bottom";
}

/**
 * Validate that tracks and contentPlacement are compatible.
 * Per Silk's logic: when both are provided, contentPlacement must match tracks
 * (or be "center"). Array tracks require contentPlacement="center".
 *
 * @param {string|Array<string>} tracks - Track direction
 * @param {string} contentPlacement - Content placement
 * @returns {boolean} Whether the combination is valid
 */
export function validateTracksPlacement(tracks, contentPlacement) {
  if (!tracks || !contentPlacement) {
    return true;
  }

  // Center placement is valid with any track
  if (contentPlacement === "center") {
    return true;
  }

  const normalizedTrack = normalizeTrack(tracks);

  // Array tracks (normalized to horizontal/vertical) require center placement
  if (normalizedTrack === "horizontal" || normalizedTrack === "vertical") {
    // eslint-disable-next-line no-console
    console.warn(
      `d-sheet: contentPlacement "${contentPlacement}" cannot be used with array tracks. ` +
        `Use "center" for contentPlacement with bidirectional tracks.`
    );
    return false;
  }

  if (
    tracks === "top" &&
    contentPlacement !== "top" &&
    contentPlacement !== "center"
  ) {
    // eslint-disable-next-line no-console
    console.warn(
      `d-sheet: contentPlacement "${contentPlacement}" cannot be used with tracks="top". ` +
        `Use "top" or "center" for contentPlacement.`
    );
    return false;
  }
  if (
    tracks === "bottom" &&
    contentPlacement !== "bottom" &&
    contentPlacement !== "center"
  ) {
    // eslint-disable-next-line no-console
    console.warn(
      `d-sheet: contentPlacement "${contentPlacement}" cannot be used with tracks="bottom". ` +
        `Use "bottom" or "center" for contentPlacement.`
    );
    return false;
  }
  if (
    tracks === "left" &&
    contentPlacement !== "left" &&
    contentPlacement !== "center"
  ) {
    // eslint-disable-next-line no-console
    console.warn(
      `d-sheet: contentPlacement "${contentPlacement}" cannot be used with tracks="left". ` +
        `Use "left" or "center" for contentPlacement.`
    );
    return false;
  }
  if (
    tracks === "right" &&
    contentPlacement !== "right" &&
    contentPlacement !== "center"
  ) {
    // eslint-disable-next-line no-console
    console.warn(
      `d-sheet: contentPlacement "${contentPlacement}" cannot be used with tracks="right". ` +
        `Use "right" or "center" for contentPlacement.`
    );
    return false;
  }

  return true;
}
