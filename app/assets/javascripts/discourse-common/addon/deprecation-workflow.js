const DEPRECATION_WORKFLOW = [
  {
    handler: "silence",
    matchId: "ember-this-fallback.this-property-fallback",
  },
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "silence",
    matchId: "discourse.fontawesome-6-upgrade",
  },
  {
    handler: "silence",
    matchId: "discourse.post-menu-widget-overrides",
  },
];

export default DEPRECATION_WORKFLOW;
