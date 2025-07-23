import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import DurationSelector from "../ai-quota-duration-selector";

export default class AiLlmQuotaModal extends Component {
  @service site;

  @action
  save(data) {
    const quota = { ...data };
    quota.group_name = this.site.groups.findBy("id", data.group_id).name;
    quota.llm_model_id = this.args.model.id;

    this.args.model.addItemToCollection(quota);
    this.args.closeModal();

    if (this.args.model.onSave) {
      this.args.model.onSave();
    }
  }

  get availableGroups() {
    const existingQuotaGroupIds =
      this.args.model.llm.llm_quotas.map((q) => q.group_id) || [];

    return this.site.groups.filter(
      (group) => !existingQuotaGroupIds.includes(group.id) && group.id !== 0
    );
  }

  @cached
  get quota() {
    return {
      group_id: null,
      llm_model_id: null,
      max_tokens: null,
      max_usages: null,
      duration_seconds: moment.duration(1, "day").asSeconds(),
    };
  }

  @action
  setGroupId(field, groups) {
    field.set(groups[0]);
  }

  @action
  validateForm(data, { addError, removeError }) {
    if (!data.max_tokens && !data.max_usages) {
      addError("max_tokens", {
        title: i18n("discourse_ai.llms.quotas.max_tokens"),
        message: i18n("discourse_ai.llms.quotas.max_tokens_required"),
      });
      addError("max_usages", {
        title: i18n("discourse_ai.llms.quotas.max_usages"),
        message: i18n("discourse_ai.llms.quotas.max_usages_required"),
      });
    } else {
      removeError("max_tokens");
      removeError("max_usages");
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_ai.llms.quotas.add_title"}}
      @closeModal={{@closeModal}}
      class="ai-llm-quota-modal"
    >
      <:body>
        <Form
          @validate={{this.validateForm}}
          @onSubmit={{this.save}}
          @data={{this.quota}}
          as |form data|
        >
          <form.Field
            @name="group_id"
            @title={{i18n "discourse_ai.llms.quotas.group"}}
            @validation="required"
            @format="large"
            as |field|
          >
            <field.Custom>
              <GroupChooser
                @value={{data.group_id}}
                @content={{this.availableGroups}}
                @onChange={{fn this.setGroupId field}}
                @options={{hash maximum=1}}
              />
            </field.Custom>
          </form.Field>

          <form.Field
            @name="max_tokens"
            @title={{i18n "discourse_ai.llms.quotas.max_tokens"}}
            @tooltip={{i18n "discourse_ai.llms.quotas.max_tokens_help"}}
            @format="large"
            as |field|
          >
            <field.Input @type="number" min="1" />
          </form.Field>

          <form.Field
            @name="max_usages"
            @title={{i18n "discourse_ai.llms.quotas.max_usages"}}
            @tooltip={{i18n "discourse_ai.llms.quotas.max_usages_help"}}
            @format="large"
            as |field|
          >
            <field.Input @type="number" min="1" />
          </form.Field>

          <form.Field
            @name="duration_seconds"
            @title={{i18n "discourse_ai.llms.quotas.duration"}}
            @validation="required"
            @format="large"
            as |field|
          >
            <field.Custom>
              <DurationSelector
                @value={{data.duration_seconds}}
                @onChange={{field.set}}
              />
            </field.Custom>
          </form.Field>

          <form.Submit
            @label="discourse_ai.llms.quotas.add"
            class="btn-primary"
          />
        </Form>
      </:body>
    </DModal>
  </template>
}
