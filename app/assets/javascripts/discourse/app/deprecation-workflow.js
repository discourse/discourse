/**
 * Valid environment names for deprecation workflows.
 * @type {string[]}
 */
const VALID_ENVS = [
  "development",
  "qunit-test",
  "rails-test",
  "test",
  "production",
  "unset",
];

/**
 * Valid handler types specifically for Ember CLI workflows.
 * @type {string[]}
 */
const VALID_EMBER_CLI_WORKFLOW_HANDLERS = ["silence", "log", "throw"];

/**
 * Valid handler types for deprecation workflows.
 * @type {string[]}
 */
const VALID_HANDLERS = [...VALID_EMBER_CLI_WORKFLOW_HANDLERS, "counter"];

/**
 * Handles deprecation workflows in Discourse.
 * @class
 */
export class DiscourseDeprecationWorkflow {
  #environment;
  #workflows;
  #activeWorkflows;

  /**
   * Creates a new DiscourseDeprecationWorkflow instance.
   * @param {Object[]} workflows - Array of workflow configurations
   * @param {(string|string[])} workflows[].handler - Handler type(s) for the workflow
   * @param {(string|RegExp)} workflows[].matchId - ID or pattern to match deprecations
   * @param {(string|string[])} [workflows[].env] - Environment(s) where the workflow applies
   */
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

  /**
   * Gets the list of active workflows.
   * @return {Object[]} Array of active workflow configurations
   */
  get list() {
    return this.#activeWorkflows;
  }

  /**
   * Gets Ember-specific workflows formatted for Ember CLI.
   * @return {Object[]} Array of formatted Ember workflow configurations
   */
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
        VALID_EMBER_CLI_WORKFLOW_HANDLERS.includes(workflow.handler)
      );
  }

  /**
   * Sets the current environment and updates active workflows.
   * @param {Object} environment - Environment object
   */
  setEnvironment(environment) {
    this.#environment = environment;
    this.#updateActiveWorkflows();
  }

  /**
   * Checks if a deprecation should be logged.
   * @param {string} deprecationId - ID of the deprecation
   * @return {boolean} True if deprecation should be logged
   */
  shouldLog(deprecationId) {
    const workflow = this.#find(deprecationId);
    return !workflow || workflow.handler.includes("log");
  }

  /**
   * Checks if a deprecation should be silenced.
   * @param {string} deprecationId - ID of the deprecation
   * @return {boolean} True if deprecation should be silenced
   */
  shouldSilence(deprecationId) {
    const workflow = this.#find(deprecationId);
    return !!workflow?.handler?.includes("silence");
  }

  /**
   * Checks if a deprecation should be counted.
   * @param {string} deprecationId - ID of the deprecation
   * @return {boolean} True if deprecation should be counted
   */
  shouldCount(deprecationId) {
    const workflow = this.#find(deprecationId);
    if (!workflow) {
      return true;
    }

    const silenced = workflow.handler?.includes("silence") ?? false;
    const count = workflow.handler?.includes("counter") ?? false;

    return !silenced || count;
  }

  /**
   * Checks if a deprecation should throw an error.
   * @param {string} deprecationId - ID of the deprecation
   * @param {boolean} [includeUnsilenced=false] - Whether to throw for unsilenced deprecations
   * @return {boolean} True if deprecation should throw
   */
  shouldThrow(deprecationId, includeUnsilenced = false) {
    const workflow = this.#find(deprecationId);

    if (includeUnsilenced) {
      return !this.shouldSilence(deprecationId);
    }

    return !!workflow?.handler?.includes("throw");
  }

  /**
   * Finds the workflow matching a deprecation ID.
   * @param {string} deprecationId - ID of the deprecation
   * @return {Object|undefined} Matching workflow configuration if found
   * @private
   */
  #find(deprecationId) {
    return this.#activeWorkflows.find((workflow) => {
      if (workflow.matchId instanceof RegExp) {
        return workflow.matchId.test(deprecationId);
      }

      return workflow.matchId === deprecationId;
    });
  }

  /**
   * Updates the list of active workflows based on current environment.
   * @private
   */
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

/**
 * Singleton DiscourseDeprecationWorkflow instance containing the current deprecation handling rules
 *
 * IMPORTANT: The first match wins, so the order of the workflows is relevant.
 *
 * Each workflow config item should have:
 * @property {(string|string[])} handler - Handler type(s): "silence", "log", "throw", and/or "counter"
 * @property {(string|RegExp)} matchId - ID or pattern to match deprecations
 * @property {(string|string[])} [env] - Optional environment(s): "development", "qunit-test", "rails-test", "test", "production", "unset"
 *
 */
const DeprecationWorkflow = new DiscourseDeprecationWorkflow([
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "silence",
    matchId: "deprecate-import-meta-from-ember",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.filterBy",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.findBy",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.mapBy",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.reject",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.rejectBy",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.sortBy",
  },
  {
    handler: "log",
    matchId: "discourse.native-array-extensions.without",
  },
  {
    handler: ["silence", "counter"],
    matchId: /^discourse\.native-array-extensions\..+$/,
    env: ["test"],
  },
  {
    handler: "silence",
    matchId: /^discourse\.native-array-extensions\..+$/,
    env: ["development", "production"],
  },
]);

export default DeprecationWorkflow;
