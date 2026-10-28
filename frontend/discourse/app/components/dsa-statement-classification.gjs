import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DsaClassificationConfirmation from "discourse/components/dialog-messages/dsa-classification-confirmation";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class DsaStatementClassification extends Component {
  @service dialog;
  @service toasts;

  @tracked saving = false;

  formData = {};

  get classification() {
    return this.args.reviewable.dsa_classification;
  }

  @action
  cancel() {
    this.args.onCancel?.();
  }

  @action
  showHelp() {
    this.dialog.alert(i18n("dsa_statements.help"));
  }

  @action
  async save(data) {
    const reviewable = this.args.reviewable;

    const statementIds = [...this.classification.statement_ids];
    const rule = this.args.classificationOptions.community_rules.find(
      (entry) => entry.id === data.community_rule
    );
    const category = this.args.classificationOptions.categories.find(
      (entry) => entry.id === data.category
    );
    const confirmed = await this.dialog.confirm({
      title: i18n("dsa_statements.confirm_title"),
      bodyComponent: DsaClassificationConfirmation,
      bodyComponentModel: { rule: rule.ground, category: category.name },
      confirmButtonLabel: "dsa_statements.save",
    });

    if (!confirmed || this.isDestroying) {
      return;
    }

    this.saving = true;
    this.args.onSavingChange?.(true);

    try {
      const response = await ajax(
        `/review/${reviewable.id}/dsa-classification`,
        {
          type: "PUT",
          data: {
            ...data,
            statement_ids: statementIds,
          },
        }
      );
      reviewable.set("reviewable_notes", response.reviewable_notes);

      if (!this.isDestroying) {
        this.cancel();
      }

      reviewable.set("dsa_classification", response.dsa_classification);
      this.toasts.success({
        duration: "short",
        data: { message: i18n("dsa_statements.saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;
      this.args.onSavingChange?.(false);
    }
  }

  <template>
    <section class="dsa-classification" ...attributes>
      {{#unless @hideHeading}}
        <div class="dsa-classification__heading">
          <h2>{{i18n "dsa_statements.title"}}</h2>
          <DButton
            class="btn-transparent"
            @action={{this.showHelp}}
            @icon="circle-question"
            @title="dsa_statements.help_title"
          />
        </div>
      {{/unless}}

      {{#if this.classification.statement_ids.length}}
        <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
          <form.Field
            @disabled={{this.saving}}
            @format="full"
            @name="community_rule"
            @title={{i18n "dsa_statements.rule"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control
              @nonePlaceholder={{i18n "dsa_statements.rule_prompt"}}
              as |select|
            >
              {{#each @classificationOptions.community_rules as |rule|}}
                <select.Option
                  @value={{rule.id}}
                >{{rule.ground}}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>

          <form.Field
            @disabled={{this.saving}}
            @format="full"
            @name="category"
            @title={{i18n "dsa_statements.category"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control
              @nonePlaceholder={{i18n "dsa_statements.category_prompt"}}
              as |select|
            >
              {{#each @classificationOptions.categories as |category|}}
                <select.Option
                  @value={{category.id}}
                >{{category.name}}</select.Option>
              {{/each}}
            </field.Control>
          </form.Field>

          <form.Actions>
            <form.Submit
              @disabled={{this.saving}}
              @label={{if
                this.saving
                "dsa_statements.saving"
                "dsa_statements.save"
              }}
            />
            {{#if @showCancel}}
              <DButton
                @action={{this.cancel}}
                @disabled={{this.saving}}
                @label="cancel"
              />
            {{/if}}
          </form.Actions>
        </Form>
      {{/if}}
    </section>
  </template>
}
