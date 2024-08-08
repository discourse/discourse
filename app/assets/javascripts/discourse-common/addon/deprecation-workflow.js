const DEPRECATION_WORKFLOW = [
  {
    handler: "silence",
    matchId: "ember-this-fallback.this-property-fallback",
  },
  { handler: "silence", matchId: "discourse.select-kit" },
  { handler: "silence", matchId: "discourse.d-section" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
];

export default DEPRECATION_WORKFLOW;
