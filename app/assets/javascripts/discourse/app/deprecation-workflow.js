import { makeArray } from "discourse/lib/helpers";

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

      const validEnvs = [
        "development",
        "qunit-test",
        "rails-test",
        "test",
        "production",
      ];
      workflow.envs = makeArray(workflow.env);
      // throw an error if envs contains an item that is not in the list: development, qunit-test, rails-test, test, production
      if (workflow.envs.length > 0) {
        const envs = workflow.envs;
        envs.forEach((env) => {
          if (!validEnvs.includes(env)) {
            throw new Error(
              `Deprecation Workflow: \`env\` ${env} must be one of ${validEnvs.join(", ")}`
            );
          }
        });
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
        const targetEnvs = workflow.envs;

        if (targetEnvs.length === 0) {
          return true;
        }

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
