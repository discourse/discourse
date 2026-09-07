import { modifier } from "ember-modifier";

function fullscreenElement() {
  return document.fullscreenElement || document.webkitFullscreenElement || null;
}

// Toggle fullscreen for an element. Must be called synchronously from a user
// gesture — the Fullscreen API consumes transient activation just like
// getDisplayMedia, so the caller has to be a plain click handler, not a
// DButton (which defers via next()). When `fallbackVideo` is set and the
// element can't go fullscreen itself, the first descendant <video> is used
// instead (iOS Safari only allows the media element to go fullscreen).
export function toggleFullscreen(element, { fallbackVideo = false } = {}) {
  if (!element) {
    return;
  }

  if (fullscreenElement()) {
    (document.exitFullscreen || document.webkitExitFullscreen)?.call(document);
    return;
  }

  if (element.requestFullscreen) {
    element.requestFullscreen().catch(() => {});
  } else if (element.webkitRequestFullscreen) {
    // Safari on macOS.
    element.webkitRequestFullscreen();
  } else if (fallbackVideo) {
    element.querySelector("video")?.webkitEnterFullscreen?.();
  }
}

// A single tile can fall back to its own <video> on iOS, where container
// fullscreen is unsupported.
export function toggleTileFullscreen(tile) {
  toggleFullscreen(tile, { fallbackVideo: true });
}

// Reports whether `element` is the current fullscreen element, updating on
// every fullscreen change so a tile can flip its enter/exit affordance.
export const trackFullscreen = modifier((element, [onChange]) => {
  const update = () => onChange(fullscreenElement() === element);

  document.addEventListener("fullscreenchange", update);
  document.addEventListener("webkitfullscreenchange", update);

  return () => {
    document.removeEventListener("fullscreenchange", update);
    document.removeEventListener("webkitfullscreenchange", update);
  };
});
