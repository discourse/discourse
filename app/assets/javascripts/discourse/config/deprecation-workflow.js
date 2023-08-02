globalThis.deprecationWorkflow = globalThis.deprecationWorkflow || {};
globalThis.deprecationWorkflow.config = {
  // We're using RAISE_ON_DEPRECATION in environment.js instead of
  // `throwOnUnhandled` here since it is easier to toggle.
  workflow: [
    { handler: "silence", matchId: "route-render-template" },
    { handler: "silence", matchId: "route-disconnect-outlet" },
    { handler: "silence", matchId: "routing.transition-methods" },
    { handler: "silence", matchId: "this-property-fallback" },
    { handler: "silence", matchId: "discourse.select-kit" },
  ],
};
