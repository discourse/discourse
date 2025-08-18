import { assert } from "@ember/debug";

class DeprecationWorkflowList {
  #workflows;

  constructor(workflows) {
    workflows.forEach((workflow) => {
      assert(
        `Deprecation Workflow: \`matchId\` ${workflow.matchId} must be a string or a regex`,
        typeof workflow.matchId === "string" ||
          workflow.matchId instanceof RegExp
      );
    });

    this.#workflows = workflows;
  }

  get list() {
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

const DEPRECATION_WORKFLOW = new DeprecationWorkflowList([
  { handler: "silence", matchId: "template-action" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "deprecate-array-prototype-extensions" }, // will be removed in Ember 6.0
  { handler: "silence", matchId: "discourse.select-kit" },
  {
    handler: "silence",
    matchId: "discourse.decorate-widget.hamburger-widget-links",
  },
  {
    handler: "test",
    matchId: /^discourse\.ember\.native-array-extensions\..+$/,
  },
]);

export default DEPRECATION_WORKFLOW;
