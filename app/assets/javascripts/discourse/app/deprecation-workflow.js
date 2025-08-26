const VALID_ENVS = [
  "development",
  "qunit-test",
  "rails-test",
  "test",
  "production",
  "unset",
];

const VALID_HANDLERS = ["silence", "log", "counter", "throw"];
const VALID_EMBER_CLI_WOPKFLOW_HANDLERS = ["silence", "log", "throw"];

export class DiscourseDeprecationWorkflow {
  // the environment is set only in the `discourse-bootstrap` initializer and `discourse/lib/environment`
  // is not available for code running in MiniRacer. This reference is initialized in the app bootstrap, in case it's
  // missing, we'll just use the deprecations that don't have any environment set
  #environment;
  #workflows;
  #activeWorkflows;

  constructor(workflows) {
    workflows.forEach((workflow) => {
      // validate the deprecation handlers
      workflow.handler ||= [];
      workflow.handler = Array.isArray(workflow.handler)
        ? workflow.handler
        : [workflow.handler];

      // throw an error if handler contains an item that is not in VALID_HANDLERS
      workflow.handler.forEach((handler) => {
        if (!VALID_HANDLERS.includes(handler)) {
          throw new Error(
            `Deprecation Workflow: \`handler\` ${handler} must be one of ${VALID_HANDLERS.join(", ")}`
          );
        }
      });

      // we also need to ensure that `log` and `silence` are not used together
      if (
        workflow.handler.includes("log") &&
        workflow.handler.includes("silence")
      ) {
        throw new Error(
          `Deprecation Workflow: \`handler\` ${workflow.handler} must not include both \`log\` and \`silence\``
        );
      }

      // validate the deprecation matchIds
      if (
        typeof workflow.matchId !== "string" &&
        !(workflow.matchId instanceof RegExp)
      ) {
        throw new Error(
          `Deprecation Workflow: \`matchId\` ${workflow.matchId} must be a string or a regex`
        );
      }

      // validate the deprecation envs
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

  get list() {
    return this.#activeWorkflows;
  }

  get emberWorkflowList() {
    return this.#activeWorkflows
      .flatMap((workflow) => {
        return workflow.handler.map((handler) => ({
          matchId: workflow.matchId,
          handler,
          env: workflow.env,
        }));
      })
      .filter((workflow) =>
        VALID_EMBER_CLI_WOPKFLOW_HANDLERS.includes(workflow.handler)
      );
  }

  setEnvironment(environment) {
    this.#environment = environment;
    this.#updateActiveWorkflows();
  }

  shouldLog(deprecationId) {
    const workflow = this.#find(deprecationId);
    return !workflow || workflow.handler.includes("log");
  }

  shouldSilence(deprecationId) {
    const workflow = this.#find(deprecationId);
    return !!workflow?.handler?.includes("silence");
  }

  shouldCount(deprecationId) {
    const workflow = this.#find(deprecationId);
    if (!workflow) {
      return true;
    }

    const silenced = workflow.handler?.includes("silence") ?? false;
    const count = workflow.handler?.includes("counter") ?? false;

    return !silenced || count;
  }

  shouldThrow(deprecationId, includeUnhandled = false) {
    const workflow = this.#find(deprecationId);
    return (
      (!workflow && includeUnhandled) || !!workflow?.handler?.includes("throw")
    );
  }

  #find(deprecationId) {
    return this.#activeWorkflows.find((workflow) => {
      if (workflow.matchId instanceof RegExp) {
        return workflow.matchId.test(deprecationId);
      }

      return workflow.matchId === deprecationId;
    });
  }

  #updateActiveWorkflows() {
    const environment = this.#environment;

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
}

const DeprecationWorkflow = new DiscourseDeprecationWorkflow([
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: ["silence", "counter"],
    matchId: /^discourse\.ember\.native-array-extensions\..+$/,
    env: ["test"],
  },
  {
    handler: "silence",
    matchId: /^discourse\.ember\.native-array-extensions\..+$/,
    env: ["development", "production"],
  },
]);

export default DeprecationWorkflow;
