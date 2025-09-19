import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

/**
 * @component ReviewableActionsForm
 *
 * A FormKit-based component for handling multiple reviewable actions
 * with dropdowns for each action bundle.
 *
 * @example
 * <ReviewableActionsForm
 *   @reviewable={{this.reviewable}}
 *   @disabled={{this.updating}}
 *   @onPerformed={{this.handleActionsPerformed}}
 * />
 */
export default class ReviewableActionsForm extends Component {
  @service toasts;
  @service currentUser;

  @tracked isSubmitting = false;

  get formData() {
    const data = {};

    // Initialize form data with first action from each bundle
    this.args.reviewable.bundled_actions.forEach((bundle) => {
      // For post actions, default to the first action
      // For user actions, check if there's a "no action" option
      const defaultAction =
        bundle.actions.find(
          (a) => a.id.includes("no_action") || a.id.includes("keep")
        ) || bundle.actions[0];

      if (defaultAction) {
        data[this.formatBundleName(bundle.id)] = defaultAction.id;
      }
    });

    return data;
  }

  /**
   * Performs the selected actions
   *
   * @param {Object} data - Form data containing selected action IDs
   */
  @action
  async performActions(data) {
    if (this.isSubmitting) {
      return;
    }

    // Filter out empty selections and collect action IDs
    const actionIds = Object.values(data).filter(Boolean);

    if (actionIds.length === 0) {
      this.toasts.error({
        data: { message: i18n("review.no_actions_selected") },
      });
      return;
    }

    this.isSubmitting = true;

    try {
      const response = await ajax(
        `/review/${this.args.reviewable.id}/perform`,
        {
          type: "PUT",
          data: {
            action_ids: actionIds,
            version: this.args.reviewable.version,
            send_email: this.args.reviewable.sendEmail,
            reject_reason: this.args.reviewable.rejectReason,
          },
        }
      );

      // Handle successful response
      if (response.reviewable_perform_result) {
        const result = response.reviewable_perform_result;

        // Update user's reviewable count
        if (result.reviewable_count !== undefined) {
          this.currentUser.updateReviewableCount(result.reviewable_count);
        }

        if (result.unseen_reviewable_count !== undefined) {
          this.currentUser.set(
            "unseen_reviewable_count",
            result.unseen_reviewable_count
          );
        }

        // Show success message
        if (result.performed_actions) {
          const successCount = result.performed_actions.filter(
            (a) => a.success
          ).length;
          this.toasts.success({
            data: {
              message: i18n("review.actions_performed", {
                count: successCount,
              }),
            },
          });
        } else {
          this.toasts.success({
            data: { message: i18n("review.action_performed") },
          });
        }

        // Notify parent component
        this.args.onPerformed?.(result);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSubmitting = false;
    }
  }

  formatBundleName(name) {
    // Convert kebab-case to snake_case for form data
    return name.replace(/-/g, "_");
  }

  <template>
    <div class="reviewable-actions-form">
      <Form @data={{this.formData}} @onSubmit={{this.performActions}} as |form|>
        {{#each @reviewable.bundled_actions as |bundle|}}
          <form.Field
            @name={{this.formatBundleName bundle.id}}
            @title={{bundle.label}}
            @showTitle={{true}}
            @validation="required"
            @format="full"
            as |field|
          >
            <field.Select as |select|>
              {{#each bundle.actions as |bundleAction|}}
                <select.Option @value={{bundleAction.id}}>
                  {{bundleAction.label}}
                </select.Option>
              {{/each}}
            </field.Select>
          </form.Field>
        {{/each}}

        <form.Submit @label="review.confirm_actions" @format="full" />
      </Form>
    </div>
  </template>
}
