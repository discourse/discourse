/**
 * Convert track direction to content placement.
 * When only tracks is provided, contentPlacement is derived from tracks.
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
      return track;
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
 * Convert content placement to track direction.
 * Inverse of trackToPlacement - when only contentPlacement is provided.
 *
 * @param {string} placement - Content placement value
 * @returns {string} Track direction
 */
export function placementToTrack(placement) {
  return placement === "center" ? "bottom" : placement;
}

/**
 * Resolve tracks and contentPlacement from partial options.
 * Handles the logic of deriving missing options from provided ones.
 *
 * @param {Object} options - Configuration options
 * @param {string} [options.tracks] - Track direction
 * @param {string} [options.contentPlacement] - Content placement
 * @param {Object} defaults - Default values
 * @param {string} defaults.tracks - Default track direction
 * @param {string} defaults.contentPlacement - Default content placement
 * @returns {{ tracks: string, contentPlacement: string }} Resolved values
 */
export function resolveTracksAndPlacement(options, defaults) {
  const hasPlacement = options.contentPlacement !== undefined;
  const hasTracks = options.tracks !== undefined;

  let tracks = defaults.tracks;
  let contentPlacement = defaults.contentPlacement;

  if (hasPlacement && !hasTracks) {
    contentPlacement = options.contentPlacement;
    tracks = placementToTrack(options.contentPlacement);
  } else if (hasTracks && !hasPlacement) {
    tracks = normalizeTrack(options.tracks);
    contentPlacement = trackToPlacement(options.tracks);
  } else if (hasPlacement && hasTracks) {
    contentPlacement = options.contentPlacement;
    tracks = normalizeTrack(options.tracks);
  }

  validateTracksPlacement(tracks, contentPlacement);
  return { tracks, contentPlacement };
}

/**
 * Validate that tracks and contentPlacement are compatible.
 * When both are provided, contentPlacement must match tracks (or be "center").
 *
 * @param {string|Array<string>} tracks - Track direction
 * @param {string} contentPlacement - Content placement
 * @returns {boolean} Whether the combination is valid
 */
export function validateTracksPlacement(tracks, contentPlacement) {
  if (!tracks || !contentPlacement) {
    return true;
  }

  const isArrayTracks = Array.isArray(tracks);
  const isCenterPlacement = contentPlacement === "center";

  // Check for edge-aligned placement with non-matching tracks
  const edgePlacements = ["top", "bottom", "left", "right"];
  for (const edge of edgePlacements) {
    if (contentPlacement === edge && tracks !== edge) {
      // eslint-disable-next-line no-console
      console.warn(
        `d-sheet: contentPlacement "${contentPlacement}" cannot be used ` +
          `with tracks="${tracks}". Use "${edge}" or "center" for contentPlacement.`
      );
      return false;
    }
  }

  // Check for bidirectional array tracks without center placement
  if (isArrayTracks && !isCenterPlacement) {
    const hasBothVertical = tracks.includes("top") && tracks.includes("bottom");
    const hasBothHorizontal =
      tracks.includes("left") && tracks.includes("right");

    if (hasBothVertical || hasBothHorizontal) {
      // eslint-disable-next-line no-console
      console.warn(
        `d-sheet: contentPlacement "${contentPlacement}" cannot be used ` +
          `with bidirectional tracks. Use "center" for contentPlacement.`
      );
      return false;
    }
  }

  return true;
}
