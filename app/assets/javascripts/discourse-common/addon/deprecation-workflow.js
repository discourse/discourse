const DEPRECATION_WORKFLOW = [
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
  {
    handler: "silence",
    matchId: "discourse.hbr-topic-list-overrides",
  },
];

export default DEPRECATION_WORKFLOW;
