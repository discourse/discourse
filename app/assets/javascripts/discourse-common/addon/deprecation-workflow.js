const DEPRECATION_WORKFLOW = [
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "deprecate-array-prototype-extensions" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "silence",
    matchId: "discourse.post-menu-widget-overrides",
  },
  {
    handler: "silence",
    matchId: "discourse.hbr-topic-list-overrides",
  },
];

export default DEPRECATION_WORKFLOW;
