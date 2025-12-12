import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";
import { parseAttributesString, serializeFromForm } from "../lib/wrap-utils";

/**
 * @typedef WrapAttributesModalArgs
 * @property {(attributes: string) => void} onApply - Callback when wrap is applied
 * @property {() => void} closeModal - Function to close the modal
 * @property {string} [initialAttributes] - Initial attributes string
 */

/**
 * @typedef WrapAttributesModalSignature
 * @property {WrapAttributesModalArgs} Args
 */

/**
 * Modal for defining wrap token attributes
 *
 * @extends {Component<WrapAttributesModalSignature>}
 */
export default class WrapAttributesModal extends Component {
  @tracked formApi;

  get initialData() {
    const initialAttrs = this.args.model?.initialAttributes || "";
    const parsedAttrs = parseAttributesString(initialAttrs);
    return {
      name: parsedAttrs.wrap || "",
      attributes: Object.entries(parsedAttrs)
        .filter(([key]) => key !== "wrap")
        .map(([key, value]) => ({ key, value })),
    };
  }

  @action
  onSubmit(data) {
    const attrsString = serializeFromForm(data.name, data.attributes);
    this.args.model.onApply(attrsString);
    this.args.closeModal();
  }

  @action
  unwrap() {
    this.args.model.onRemove?.();
    this.args.closeModal();
  }

  get hasAttributeRows() {
    return this.formApi?.get("attributes")?.length > 0;
  }

  @action
  onRegisterApi(api) {
    this.formApi = api;
  }

  @action
  submitForm() {
    this.formApi?.submit();
  }

  @action
  cancel() {
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "composer.wrap_modal.title"}}
      @closeModal={{@closeModal}}
      class="wrap-attributes-modal"
    >
      <:body>
        <Form
          @data={{this.initialData}}
          @onSubmit={{this.onSubmit}}
          @onRegisterApi={{this.onRegisterApi}}
          as |form|
        >
          <form.Field
            @name="name"
            @title={{i18n "composer.wrap_modal.name_label"}}
            as |field|
          >
            <field.Input @type="text" autocomplete="off" />
          </form.Field>

          <form.Section @title={{i18n "composer.wrap_modal.attributes_label"}}>
            {{#unless this.hasAttributeRows}}
              <div>
                {{i18n "composer.wrap_modal.no_attributes"}}
              </div>
            {{/unless}}

            <form.Collection @name="attributes" as |collection index|>
              <collection.Object as |object|>
                <div class="wrap-modal__attribute-row">
                  <object.Field
                    @name="key"
                    @title="Key"
                    @validation="required"
                    as |field|
                  >
                    <field.Input @type="text" />
                  </object.Field>

                  <object.Field
                    @name="value"
                    @title="Value"
                    @validation="required"
                    as |field|
                  >
                    <field.Input @type="text" />
                  </object.Field>

                  <DButton
                    @action={{fn collection.remove index}}
                    @icon="trash-can"
                    class="btn-default btn-small"
                    @title="composer.wrap_modal.remove_attribute"
                  />
                </div>
              </collection.Object>
            </form.Collection>

            <form.Button
              @action={{fn
                form.addItemToCollection
                "attributes"
                (hash key="" value="")
              }}
              class="btn-default btn-small"
            >
              {{i18n "composer.wrap_modal.add_attribute"}}
            </form.Button>
          </form.Section>

        </Form>
      </:body>
      <:footer>
        <DButton
          @action={{this.submitForm}}
          @label="composer.wrap_modal.apply"
          class="btn-primary"
        />
        <DButton @action={{this.cancel}} @label="cancel" class="btn-default" />
        {{#if @model.onRemove}}
          <DButton
            @action={{this.unwrap}}
            @label="composer.wrap_modal.unwrap"
            class="btn-danger wrap-attributes-modal__unwrap"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
