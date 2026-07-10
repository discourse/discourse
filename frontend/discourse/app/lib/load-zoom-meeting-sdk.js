/*
Plugins & themes are unable to async-import npm modules directly.
This wrapper provides them with a way to use the Zoom Meeting SDK, while keeping the `import()` in core's codebase.
*/

// Client View (`ZoomMtg`) - renders the full Zoom client UI.
export async function loadZoomMeetingSdk() {
  return (await import("@zoom/meetingsdk")).ZoomMtg;
}

// Component View (`ZoomMtgEmbedded`) - embeds Zoom inside a container element.
export async function loadZoomMeetingSdkEmbedded() {
  return (await import("@zoom/meetingsdk/embedded")).default;
}
