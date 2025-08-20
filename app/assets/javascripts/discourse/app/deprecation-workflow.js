const VALID_ENVS = [
  "development",
  "qunit-test",
  "rails-test",
  "test",
  "production",
  "unset",
];

export class DiscourseDeprecationWorkflow {
  // enviroment is set only in the `discourse-bootstrap` initializer and `discourse/lib/environment`
  // is not available for code running in MiniRacer. This reference is initialized in the app bootstrap, in case it's
  // missing we'll just use the deprecations that don't have any environment set
  #enviroment;
  #workflows;
  #activeWorkflows;

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

      workflow.env ||= [];
      workflow.env = Array.isArray(workflow.env)
        ? workflow.env
        : [workflow.env];

      // throw an error if env contains an item that is not in VALID_ENVS
      workflow.env.forEach((env) => {
        if (!VALID_ENVS.includes(env)) {
          throw new Error(
            `Deprecation Workflow: \`env\` ${env} must be one of ${VALID_ENVS.join(", ")}`
          );
        }
      });
    });

    this.#workflows = workflows;
    this.#updateActiveWorkflows();
  }

  #updateActiveWorkflows() {
    const environment = this.#enviroment;

    this.#activeWorkflows = this.#workflows.filter((workflow) => {
      let targetEnvs = workflow.env;

      if (targetEnvs.length === 0) {
        return true;
      }

      if (!environment) {
        return targetEnvs.includes("unset");
      }

      if (environment.isProduction()) {
        return targetEnvs.includes("production");
      }

      if (environment.isTesting()) {
        return targetEnvs.includes("qunit-test") || targetEnvs.includes("test");
      }

      if (environment.isRailsTesting()) {
        return targetEnvs.includes("rails-test") || targetEnvs.includes("test");
      }

      return targetEnvs.includes("development");
    });
  }

  get list() {
    return this.#activeWorkflows;
  }

  find(deprecationId) {
    return this.#activeWorkflows.find((workflow) => {
      if (workflow.matchId instanceof RegExp) {
        return workflow.matchId.test(deprecationId);
      }

      return workflow.matchId === deprecationId;
    });
  }

  setEnvironment(environment) {
    this.#enviroment = environment;
    this.#updateActiveWorkflows();
  }
}

const DeprecationWorkflow = new DiscourseDeprecationWorkflow([
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "deprecate-array-prototype-extensions" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "throw",
    matchId: /^discourse\.ember\.native-array-extensions\..+$/,
    env: ["development"],
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

export default DeprecationWorkflow;
