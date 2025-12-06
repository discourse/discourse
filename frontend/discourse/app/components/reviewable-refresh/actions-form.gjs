import Component from "@glimmer/component";
import { action } from "@ember/object";
import Form from "discourse/components/form";

/**
 * @component ReviewableActionsForm
 *
 * A component for generating a form for a single reviewable action bundle.
 *
 * @example
 * <ReviewableActionsForm
 *   @bundle={{bundle}}
 *   @performAction={{this.performAction}}
 *   @updating={{this.updating}}
 * />
 */
export default class ReviewableActionsForm extends Component {
  get formData() {
    const data = {};

    const selectedIndex = this.args.bundle.selected_action
      ? this.args.bundle.actions.findIndex(
          (a) => a.server_action === this.args.bundle.selected_action
        )
      : 0;

    data[this.formatBundleName(this.args.bundle.id)] =
      this.args.bundle.actions[selectedIndex > -1 ? selectedIndex : 0].id;

    return data;
  }

  /**
   * Performs the selected action
   *
   * @param {Object} data - Form data containing selected action ID
   */
  @action
  async performActions(data) {
    if (this.args.disabled) {
      return;
    }

    await this.args.performAction(
      this.args.bundle.actions.find(
        (a) => a.id === data[this.formatBundleName(this.args.bundle.id)]
      )
    );
  }

  formatBundleName(name) {
    // Convert kebab-case to snake_case for form data
    return name.replace(/-/g, "_");
  }

  <template>
    <div class="reviewable-actions-form">
      <Form
        data-bundle-id={{@bundle.id}}
        @data={{this.formData}}
        @onSubmit={{this.performActions}}
        as |form|
      >
        <form.Field
          @name={{this.formatBundleName @bundle.id}}
          @title={{@bundle.label}}
          @showTitle={{true}}
          @validation="required"
          @format="full"
          as |field|
        >
          <field.Select as |select|>
            {{#each @bundle.actions as |bundleAction|}}
              <select.Option @value={{bundleAction.id}}>
                {{bundleAction.label}}
              </select.Option>
            {{/each}}
          </field.Select>
        </form.Field>

        <form.Submit
          @icon="check"
          @forwardEvent="true"
          class="btn-primary form-kit__button"
          type="submit"
          @isLoading={{@updating}}
        />
      </Form>
    </div>
  </template>
}
