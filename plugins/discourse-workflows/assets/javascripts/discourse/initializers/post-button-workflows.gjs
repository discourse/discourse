import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const ANCHOR_KEYS = {
  read: "read",
  like: "like",
  copy_link: "copyLink",
  flag: "flag",
  edit: "edit",
  bookmark: "bookmark",
  delete: "delete",
  admin: "admin",
  reply: "reply",
};

function dagPosition(workflow, context, postMenuOrder) {
  const position = workflow.position;

  if (position === "first") {
    return { before: context.firstButtonKey };
  }

  if (position === "more_menu") {
    return {
      before: context.lastHiddenButtonKey,
      after: context.secondLastHiddenButtonKey,
    };
  }

  const match = position?.match(/^(before|after)_(.+)$/);
  if (match) {
    const anchor = ANCHOR_KEYS[match[2]];
    if (!anchor) {
      // key from plugin or theme
      return { [match[1]]: match[2] };
    }

    const index = postMenuOrder.indexOf(anchor);
    if (index === -1) {
      // key not in site menu
      return { [match[1]]: anchor };
    }

    if (match[1] === "before") {
      const previous = postMenuOrder[index - 1];
      return previous
        ? { before: anchor, after: previous }
        : { before: anchor };
    }

    return {
      after: anchor,
      before: postMenuOrder[index + 1] || context.buttonKeys.SHOW_MORE,
    };
  }

  return undefined;
}

function buildButtonComponent(workflow) {
  const className = `post-action-menu__workflow-post-button workflow-post-button-${workflow.workflow_id}`;

  class WorkflowPostButton extends Component {
    @service dialog;

    @tracked triggering = false;

    @action
    trigger() {
      if (workflow.confirmation) {
        this.dialog.yesNoConfirm({
          message:
            workflow.confirmation_message ||
            i18n(
              "discourse_workflows.post_button.confirmation_default_message"
            ),
          didConfirm: () => this.triggerWorkflow(),
        });
      } else {
        return this.triggerWorkflow();
      }
    }

    async triggerWorkflow() {
      this.triggering = true;
      try {
        await ajax("/discourse-workflows/trigger-post-button", {
          type: "POST",
          data: {
            trigger_node_id: workflow.trigger_node_id,
            post_id: this.args.post.id,
          },
        });
      } catch (error) {
        popupAjaxError(error);
      } finally {
        this.triggering = false;
      }
    }

    <template>
      <DButton
        class={{className}}
        ...attributes
        @action={{this.trigger}}
        @disabled={{this.triggering}}
        @icon={{if workflow.icon workflow.icon "bolt"}}
        @translatedTitle={{workflow.label}}
        @translatedLabel={{if @showLabel workflow.label}}
      />
    </template>
  }

  if (workflow.position === "more_menu") {
    WorkflowPostButton.hidden = true;
  }

  return WorkflowPostButton;
}

export default {
  name: "discourse-workflows-post-button",

  initialize(container) {
    const site = container.lookup("service:site");
    const workflows = site.post_button_workflows || [];

    if (!workflows.length) {
      return;
    }

    const siteSettings = container.lookup("service:site-settings");
    const postMenuOrder = (siteSettings.post_menu || "")
      .split("|")
      .filter(Boolean);

    const buttons = workflows.map((workflow) => ({
      key: `workflow-post-button-${workflow.workflow_id}-${workflow.trigger_node_id}`,
      workflow,
      component: buildButtonComponent(workflow),
    }));

    withPluginApi((api) => {
      api.registerValueTransformer(
        "post-menu-buttons",
        ({ value: dag, context }) => {
          buttons.forEach(({ key, workflow, component }) => {
            dag.add(
              key,
              component,
              dagPosition(workflow, context, postMenuOrder)
            );
          });
        }
      );
    });
  },
};
