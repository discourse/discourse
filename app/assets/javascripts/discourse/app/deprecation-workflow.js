const DEPRECATION_WORKFLOW = [
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "deprecate-array-prototype-extensions" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  // TODO (glimmer-post-stream): remove the silence once upgrade notes are ready and we start rolling out the new version
  {
    handler: "silence",
    matchId: "discourse.post-stream-widget-overrides",
  },
];

export default DEPRECATION_WORKFLOW;
