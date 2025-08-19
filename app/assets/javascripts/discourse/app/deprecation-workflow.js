class DiscourseDeprecationWorkflow {
  #filtered = false;
  #workflows;

  constructor(workflows) {
    workflows.forEach((workflow) => {
      if (
        typeof workflow.matchId !== "string" &&
        !(workflow.matchId instanceof RegExp)
      ) {
        throw new Error(
          `Deprecation Workflow: \`matchId\` ${workflow.matchId} must be a string or a regex`
        );
      }
    });

    this.#workflows = workflows;
  }

  get list() {
    if (this.#filtered) {
      return this.#workflows;
    }

    this.#workflows = this.#workflows.filter((workflow) => {
      try {
        const environment = require("discourse/lib/environment");
        let targetEnvs = workflow.env;

        if (!targetEnvs || targetEnvs.length === 0) {
          return true;
        }

        targetEnvs = Array.isArray(targetEnvs) ? targetEnvs : [targetEnvs];

        if (environment.isProduction()) {
          return targetEnvs.includes("production");
        }

        if (environment.isTesting()) {
          return (
            targetEnvs.includes("qunit-test") || targetEnvs.includes("test")
          );
        }

        if (environment.isRailsTesting()) {
          return (
            targetEnvs.includes("rails-test") || targetEnvs.includes("test")
          );
        }

        return targetEnvs.includes("development");
      } catch {
        return false;
      }
    });
    this.#filtered = true;

    return this.#workflows;
  }

  find(deprecationId) {
    return this.#workflows.find((workflow) => {
      if (workflow.matchId instanceof RegExp) {
        return workflow.matchId.test(deprecationId);
      }

      return workflow.matchId === deprecationId;
    });
  }
}

const DEPRECATION_WORKFLOW = new DiscourseDeprecationWorkflow([
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "deprecate-array-prototype-extensions" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "silence|counter",
    matchId: /^discourse\.ember\.native-array-extensions\..+$/,
    env: ["test"],
  },
  {
    handler: "silence",
    matchId: /^discourse\.ember\.native-array-extensions\..+$/,
    env: ["production"],
  },
]);

export default DEPRECATION_WORKFLOW;
