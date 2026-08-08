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
  const hasPlacement = Boolean(options.contentPlacement);
  const hasTracks = Boolean(options.tracks);

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

  validateTracksPlacement(options.tracks, options.contentPlacement);
  return { tracks, contentPlacement };
}
export function validateTracksPlacement(tracks, contentPlacement) {
  const placement = contentPlacement === undefined ? null : contentPlacement;
  const placementIncludes = (value) => placement?.includes(value);
  const hasMismatchedEdge = ["top", "bottom", "left", "right"].some(
    (edge) => placementIncludes(edge) && tracks && tracks !== edge
  );
  const hasBidirectionalTracks =
    !placementIncludes("center") &&
    tracks &&
    ((tracks.includes("top") && tracks.includes("bottom")) ||
      (tracks.includes("left") && tracks.includes("right")));

  if (hasMismatchedEdge || hasBidirectionalTracks) {
    throw new Error(
      `'placement' prop value '${placement}' cannot be used with 'tracks' prop value '${tracks}'.`
    );
  }

  return true;
}
