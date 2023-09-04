globalThis.deprecationWorkflow = globalThis.deprecationWorkflow || {};
globalThis.deprecationWorkflow.config = {
  // We're using RAISE_ON_DEPRECATION in environment.js instead of
  // `throwOnUnhandled` here since it is easier to toggle.
  workflow: [
    { handler: "silence", matchId: "route-render-template" },
    { handler: "silence", matchId: "route-disconnect-outlet" },
    { handler: "silence", matchId: "this-property-fallback" }, // We can unsilence this once ember-this-fallback works with themes
    {
      handler: "silence",
      matchId: "ember-this-fallback.this-property-fallback",
    },
    { handler: "silence", matchId: "discourse.select-kit" },
  ],
};
