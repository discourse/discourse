import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { AUTO_GROUPS } from "discourse/lib/constants";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";
import DurationSelector from "../ai-quota-duration-selector";

export default class AiLlmQuotaModal extends Component {
  @service site;

  get availableGroups() {
    const existingQuotaGroupIds =
      this.args.model.llm.llm_quotas.map((q) => q.group_id) || [];

    return this.site.groups.filter(
      (group) =>
        !existingQuotaGroupIds.includes(group.id) &&
        group.id !== AUTO_GROUPS.everyone.id
    );
  }

  @cached
  get quota() {
    return {
      group_id: null,
      llm_model_id: null,
      max_tokens: null,
      max_usages: null,
      max_cost: null,
      duration_seconds: moment.duration(1, "day").asSeconds(),
    };
  }

  @action
  save(data) {
    const quota = { ...data };
    quota.group_name = this.site.groupName(data.group_id);
    quota.llm_model_id = this.args.model.id;

    this.args.model.addItemToCollection(quota);
    this.args.closeModal();

    if (this.args.model.onSave) {
      this.args.model.onSave();
    }
  }

  @action
  setGroupId(field, groups) {
    field.set(groups[0]);
  }

  @action
  validateForm(data, { addError, removeError }) {
    if (!data.max_tokens && !data.max_usages && !data.max_cost) {
      addError("max_tokens", {
        title: i18n("discourse_ai.llms.quotas.max_tokens"),
        message: i18n("discourse_ai.llms.quotas.max_tokens_required"),
      });
      addError("max_usages", {
        title: i18n("discourse_ai.llms.quotas.max_usages"),
        message: i18n("discourse_ai.llms.quotas.max_usages_required"),
      });
      addError("max_cost", {
        title: i18n("discourse_ai.llms.quotas.max_cost"),
        message: i18n("discourse_ai.llms.quotas.max_cost_required"),
      });
    } else {
      removeError("max_tokens");
      removeError("max_usages");
      removeError("max_cost");
    }
  }

  <template>
    <DModal
      class="ai-llm-quota-modal"
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_ai.llms.quotas.add_title"}}
    >
      <:body>
        <Form
          @data={{this.quota}}
          @onSubmit={{this.save}}
          @validate={{this.validateForm}}
          as |form data|
        >
          <form.Field
            @format="large"
            @name="group_id"
            @title={{i18n "discourse_ai.llms.quotas.group"}}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <GroupChooser
                @content={{this.availableGroups}}
                @onChange={{fn this.setGroupId field}}
                @options={{hash maximum=1}}
                @value={{data.group_id}}
              />
            </field.Control>
          </form.Field>

          <form.Field
            @format="large"
            @name="max_tokens"
            @title={{i18n "discourse_ai.llms.quotas.max_tokens"}}
            @tooltip={{i18n "discourse_ai.llms.quotas.max_tokens_help"}}
            @type="input-number"
            as |field|
          >
            <field.Control min="1" />
          </form.Field>

          <form.Field
            @format="large"
            @name="max_usages"
            @title={{i18n "discourse_ai.llms.quotas.max_usages"}}
            @tooltip={{i18n "discourse_ai.llms.quotas.max_usages_help"}}
            @type="input-number"
            as |field|
          >
            <field.Control min="1" />
          </form.Field>

          <form.Field
            @format="large"
            @name="max_cost"
            @title={{i18n "discourse_ai.llms.quotas.max_cost"}}
            @tooltip={{i18n "discourse_ai.llms.quotas.max_cost_help"}}
            @type="input-number"
            as |field|
          >
            <field.Control min="0.01" step="0.01" />
          </form.Field>

          <form.Field
            @format="large"
            @name="duration_seconds"
            @title={{i18n "discourse_ai.llms.quotas.duration"}}
            @type="custom"
            @validation="required"
            as |field|
          >
            <field.Control>
              <DurationSelector
                @onChange={{field.set}}
                @value={{data.duration_seconds}}
              />
            </field.Control>
          </form.Field>

          <form.Submit
            class="btn-primary"
            @label="discourse_ai.llms.quotas.add"
          />
        </Form>
      </:body>
    </DModal>
  </template>
}
