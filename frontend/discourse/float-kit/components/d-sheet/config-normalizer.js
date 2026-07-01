function trackToPlacement(track) {
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
function normalizeTrack(track) {
  if (Array.isArray(track)) {
    return track.includes("left") ? "horizontal" : "vertical";
  }
  return track;
}
export function placementToAttribute(placement) {
  switch (placement) {
    case "top":
      return "start";
    case "bottom":
      return "end";
    case "left":
      return "left";
    case "right":
      return "right";
    case "center":
      return "center";
    default:
      return "end";
  }
}
function placementToTrack(placement) {
  return placement === "center" ? "bottom" : placement;
}
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
