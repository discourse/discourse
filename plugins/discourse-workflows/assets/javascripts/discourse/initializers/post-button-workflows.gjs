import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { registerDestructor, unregisterDestructor } from "@ember/destroyable";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { withPluginApi } from "discourse/lib/plugin-api";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const FEEDBACK_TIMEOUT_MS = 60 * 60 * 1000;
const TERMINAL_STATUSES = ["success", "error", "rate_limited", "skipped"];

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
    @service currentUser;
    @service dialog;
    @service messageBus;
    @service toasts;

    @tracked triggering = false;

    @action
    trigger() {
      if (this.triggering) {
        return;
      }

      if (workflow.confirmation) {
        this.dialog.yesNoConfirm({
          message:
            workflow.confirmation_message ||
            i18n(
              "discourse_workflows.post_button.confirmation_default_message"
            ),
          didConfirm: () => this.#triggerWorkflow(),
        });
      } else {
        return this.#triggerWorkflow();
      }
    }

    async #triggerWorkflow() {
      if (this.triggering) {
        return;
      }

      const requestId = crypto.randomUUID?.();
      const stopFeedback = requestId && this.#watchFeedback(requestId);
      this.triggering = true;
      this.toasts.info({
        key: "workflow-post-button-starting",
        data: { message: i18n("discourse_workflows.post_button.starting") },
      });
      try {
        await ajax("/discourse-workflows/trigger-post-button", {
          type: "POST",
          data: {
            workflow_id: workflow.workflow_id,
            trigger_node_id: workflow.trigger_node_id,
            post_id: this.args.post.id,
            ...(requestId && {
              client_id: this.messageBus.clientId,
              request_id: requestId,
            }),
          },
        });
      } catch (error) {
        stopFeedback?.();
        popupAjaxError(error);
      } finally {
        this.triggering = false;
      }
    }

    #watchFeedback(requestId) {
      const owner = getOwner(this);
      const { messageBus, toasts } = this;
      const channel = `/discourse-workflows/post-button/${this.currentUser.id}/${requestId}`;
      const onResult = (data) => {
        const status = data?.status;
        if (!TERMINAL_STATUSES.includes(status)) {
          return;
        }
        stop();
        if (status !== "success") {
          toasts.error({
            key: `workflow-post-button-${requestId}`,
            duration: "long",
            data: {
              message: i18n(
                `discourse_workflows.post_button.${status === "rate_limited" ? status : "error"}`
              ),
            },
          });
        }
      };
      const teardown = () => {
        clearTimeout(timeout);
        messageBus.unsubscribe(channel, onResult);
      };
      let active = true;
      const stop = () => {
        if (active) {
          active = false;
          unregisterDestructor(owner, teardown);
          teardown();
        }
      };
      const timeout = setTimeout(stop, FEEDBACK_TIMEOUT_MS);
      registerDestructor(owner, teardown);
      // A unique channel can replay a fast result without replaying older runs.
      messageBus.subscribe(channel, onResult, 0);
      return stop;
    }

    <template>
      <DButton
        class={{className}}
        ...attributes
        @action={{this.trigger}}
        @disabled={{this.triggering}}
        @icon={{if workflow.icon workflow.icon "bolt"}}
        @isLoading={{this.triggering}}
        @translatedLabel={{if @showLabel workflow.label}}
        @translatedTitle={{workflow.label}}
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
            if (
              workflow.post_number != null &&
              workflow.post_number !== context.post.post_number
            ) {
              return;
            }

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
