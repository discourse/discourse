const DEPRECATION_WORKFLOW = [
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "silence",
    matchId: "deprecate-import-meta-from-ember",
  },
];

export default DEPRECATION_WORKFLOW;
