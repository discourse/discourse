// Registered as a top-level route (rather than nested under `topic`) because the
// core topic template has no router `{{outlet}}` for a child route to render
// into. This renders the full-page Zoom view into the application's main outlet.
export default function () {
  this.route("topic-zoom", { path: "/t/:slug/:topic_id/zoom" });
}
