globalThis.deprecationWorkflow = globalThis.deprecationWorkflow || {};
globalThis.deprecationWorkflow.config = {
  // We're using RAISE_ON_DEPRECATION in environment.js instead of
  // `throwOnUnhandled` here since it is easier to toggle.
  workflow: [
    { handler: "silence", matchId: "ember-global" },
    { handler: "silence", matchId: "ember.built-in-components.reopen" },
    { handler: "silence", matchId: "ember.built-in-components.import" },
    { handler: "silence", matchId: "implicit-injections" },
    { handler: "silence", matchId: "route-render-template" },
    { handler: "silence", matchId: "routing.transition-methods" },
    { handler: "silence", matchId: "route-disconnect-outlet" },
    { handler: "silence", matchId: "setting-on-hash" },
    { handler: "silence", matchId: "this-property-fallback" },
    { handler: "silence", matchId: "ember.globals-resolver" },
    { handler: "silence", matchId: "globals-resolver" },
    {
      handler: "silence",
      matchId: "deprecated-run-loop-and-computed-dot-access",
    },
    {
      handler: "silence",
      matchId: "ember.built-in-components.legacy-arguments",
    },
  ],
};
