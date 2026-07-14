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
const VALID_HANDLERS = [
  ...VALID_EMBER_CLI_WORKFLOW_HANDLERS,
  "dont-throw",
  "dont-count",
  "count",
  "notify-admin",
];

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
    workflows.forEach(this.#validateWorkflow);

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
   *
   * @param {string} deprecationId - ID of the deprecation
   * @return {boolean} True if deprecation should be counted
   */
  shouldCount(deprecationId) {
    const workflow = this.#find(deprecationId);
    if (!workflow) {
      return true;
    }

    // The "dont-count" handler prevents counting specific deprecations
    // even when they would normally be counted (e.g., for test fixtures)
    if (workflow.handler?.includes("dont-count")) {
      return false;
    }

    const silenced = workflow.handler?.includes("silence") ?? false;
    const count = workflow.handler?.includes("count") ?? false;

    return !silenced || count;
  }

  /**
   * Checks if a deprecation should throw an error.
   *
   * @param {string} deprecationId - ID of the deprecation
   * @param {boolean} [includeUnsilenced=false] - Whether to throw for unsilenced deprecations
   * @return {boolean} True if deprecation should throw
   */
  shouldThrow(deprecationId, includeUnsilenced = false) {
    const workflow = this.#find(deprecationId);

    // The "dont-throw" handler prevents raising errors for specific deprecations
    // even when RAISE_ON_DEPRECATION is enabled (e.g., for test fixtures)
    if (workflow?.handler?.includes("dont-throw")) {
      return false;
    }

    if (includeUnsilenced) {
      return !this.shouldSilence(deprecationId);
    }

    return !!workflow?.handler?.includes("throw");
  }

  /**
   * Checks if a deprecation should notify admins.
   *
   * @param {string} deprecationId - ID of the deprecation
   * @return {boolean} True if deprecation should notify admins
   */
  shouldNotifyAdmin(deprecationId) {
    const workflow = this.#find(deprecationId);
    return !!workflow?.handler?.includes("notify-admin");
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

  /**
   * Validates a workflow configuration object.
   * Ensures handler types, matchId patterns, and environments are valid.
   * Automatically converts single values to arrays for handler and env properties.
   *
   * @param {Object} workflow - The workflow configuration to validate
   * @param {(string|string[])} workflow.handler - Handler type(s) for the workflow
   * @param {(string|RegExp)} workflow.matchId - ID or pattern to match deprecations
   * @param {(string|string[])} [workflow.env] - Environment(s) where the workflow applies
   * @throws {Error} If handler is not in VALID_HANDLERS list
   * @throws {Error} If incompatible handler combinations are used (e.g., "log" with "silence")
   * @throws {Error} If matchId is not a string or RegExp
   * @throws {Error} If env is not in VALID_ENVS list
   * @private
   */
  #validateWorkflow(workflow) {
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

    // validate incompatible handler combinations
    const incompatiblePairs = [
      ["log", "silence"],
      ["notify-admin", "silence"],
    ];

    for (const [handler1, handler2] of incompatiblePairs) {
      if (
        workflow.handler.includes(handler1) &&
        workflow.handler.includes(handler2)
      ) {
        throw new Error(
          `Deprecation Workflow: \`handler\` ${workflow.handler} must not include both \`${handler1}\` and \`${handler2}\``
        );
      }
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
    workflow.env = Array.isArray(workflow.env) ? workflow.env : [workflow.env];

    // throw an error if env contains an item that is not in VALID_ENVS
    workflow.env.forEach((env) => {
      if (!VALID_ENVS.includes(env)) {
        throw new Error(
          `Deprecation Workflow: \`env\` ${env} must be one of ${VALID_ENVS.join(", ")}`
        );
      }
    });
  }
}

/**
 * Singleton DiscourseDeprecationWorkflow instance containing the current deprecation handling rules
 *
 * IMPORTANT: The first match wins, so the order of the workflows is relevant.
 *
 * Each workflow config item should have:
 * @property {(string|string[])} handler - Handler type(s): "silence", "log", "throw", "dont-throw", "dont-count", "count", and/or "notify-admin"
 * @property {(string|RegExp)} matchId - ID or pattern to match deprecations
 * @property {(string|string[])} [env] - Optional environment(s): "development", "qunit-test", "rails-test", "test", "production", "unset"
 *
 * Handler types:
 * - "silence": Suppress the deprecation warning from logging
 * - "log": Allow the deprecation to be logged (default behavior)
 * - "throw": Throw an error when this deprecation occurs
 * - "dont-throw": Prevent throwing even when RAISE_ON_DEPRECATION is enabled
 * - "dont-count": Prevent counting this deprecation in metrics
 * - "count": Count this deprecation even if silenced
 * - "notify-admin": Display admin notification for this deprecation (incompatible with "silence")
 */
const workflows = [
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: /^discourse\.select-kit\.modify-select-kit-.+$/,
  },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "silence",
    matchId: "deprecate-import-meta-from-ember",
  },
  // CRITICAL DEPRECATIONS that should trigger admin warnings,
  // To keep warnings meaningful and prevent overflowing users with them,
  // we should only add values here after fixing core and official plugins
  ...[
    "discourse.add-saveable-user-option-field",
    "discourse.add-toolbar-popup-menu-options-callback",
    "discourse.add-user-menu-glyph",
    "discourse.application-show-footer",
    "discourse.avatar-utils",
    "discourse.base-url",
    "discourse.bound-date",
    "discourse.capitalize-string",
    "discourse.category-hashtags.categoryHashtagTriggerRule",
    "discourse.category-list.categories",
    "discourse.category-list.listForParent",
    "discourse.chat.addToolbarButton",
    "discourse.click-track.is-valid-link-jquery",
    "discourse.component-template-resolving",
    "discourse.composer-controller.clear-popup-menu-options-callback",
    "discourse.composer.usernames",
    "discourse.computed-html-safe",
    "discourse.create-store-helper",
    "discourse.createNewMessageViaParams",
    "discourse.createNewTopicViaParams",
    "discourse.current-theme-key",
    "discourse.d-editor.on-toolbar-create",
    "discourse.d-popover",
    "discourse.d-section",
    "discourse.decorate-plugin-outlet",
    "discourse.deprecated-resolver-normalization",
    "discourse.discourse-module",
    "discourse.discovery-topics-controller",
    "discourse.ember-computed-decorators",
    "discourse.fa-icon",
    "discourse.form-kit.legacy-field-yield",
    "discourse.format-age",
    "discourse.formatter.update-relative-age-node-list",
    "discourse.get-owner-with-fallback",
    "discourse.get-url-helper",
    "discourse.global.site",
    "discourse.global.site-settings",
    "discourse.global.user",
    "discourse.hbs-extension",
    "discourse.es6-extension",
    "discourse.header-extra-info.needs-second-row-if",
    "discourse.header-service-topic",
    "discourse.hide-popover",
    "discourse.html-helper",
    "discourse.html-safe-helper",
    "discourse.icon-picker",
    "discourse.icon-renderer-translatedtitle",
    "discourse.inline-date",
    "discourse.is-legacy-ember",
    "discourse.jquery-cookie",
    "discourse.legacy-array-like-object.proxied-array",
    "discourse.legacy-topic-list",
    "discourse.markdown-it.whitelist",
    "discourse.nav-item.built-list-site-settings",
    "discourse.navigation-category-controller",
    "discourse.number-field",
    "discourse.offset-calculator.minimumOffset",
    "discourse.plugin-outlet-args",
    "discourse.plugin-outlet-classic-args-clash",
    "discourse.plugin-outlet-classic-hooks",
    "discourse.plugin-outlet-context-get",
    "discourse.post-stream.trigger-new-post",
    "discourse.pretty-text.registerOption",
    "discourse.qunit-helpers.jquery-selector",
    "discourse.qunit-helpers.query-all",
    "discourse.qunit.acceptance-function",
    "discourse.qunit.global-exists",
    "discourse.register-connector-class-legacy",
    "discourse.register-raw-helper",
    "discourse.register-unbound",
    "discourse.resolver-resolutions",
    "discourse.safari-hacks-disabled",
    "discourse.section-link-class-arg",
    "discourse.select-kit-resolved-components",
    "discourse.show-popover",
    "discourse.site.is-mobile-device",
    "discourse.static-viewport-initialization",
    "discourse.tag-show-controller",
    "discourse.template-action", // removed in Ember 6.0, but we have a polyfill
    "discourse.text.cook-async",
    "discourse.this-container",
    "discourse.topic-list-find",
    "discourse.topic.totalUnread",
    "discourse.uploads.display-error-for-upload",
    "discourse.user-menu.panel-component-class",
    "discourse.user.resolved-timezone",
    "discourse.user.userOptions",
    "discourse.utils-decorators-import",
    "discourse.utils-decorators-observes",
    "discourse.utils-decorators-on",
    /^discourse\.native-array-extensions\..+$/,
  ].map((matchId) => ({ handler: "notify-admin", matchId })),

  // used in system specs
  {
    handler: ["dont-count", "dont-throw", "notify-admin"],
    matchId: /fake.deprecation.*/,
    env: "test",
  },
];

const DeprecationWorkflow = new DiscourseDeprecationWorkflow(workflows);

export default DeprecationWorkflow;
