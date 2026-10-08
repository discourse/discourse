import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class DsaClassification extends Component {
  @service toasts;

  @tracked completed = false;
  @tracked editing = false;
  @tracked retrying = false;

  @cached
  get formData() {
    return {
      community_rule: this.args.classification.community_rule || "",
      category: this.args.classification.category || "",
    };
  }

  get showFailure() {
    return this.args.classification.status === "failed" && !this.editing;
  }

  @action
  edit() {
    this.editing = true;
  }

  @action
  async retry() {
    this.retrying = true;
    try {
      await ajax(`/review/${this.args.reviewableId}/dsa-retry`, {
        type: "POST",
        data: { decision_key: this.args.classification.decision_key },
      });
      await this.args.onSaved();
      this.completed = true;
      this.toasts.success({
        data: { message: i18n("review.dsa.retry_saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.retrying = false;
    }
  }

  @action
  async save(data) {
    try {
      await ajax(`/review/${this.args.reviewableId}/dsa-classification`, {
        type: "POST",
        data: {
          ...data,
          decision_key: this.args.classification.decision_key,
        },
      });
      await this.args.onSaved();
      this.completed = true;
      this.toasts.success({ data: { message: i18n("review.dsa.saved") } });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    {{#unless this.completed}}
      <section class="dsa-classification" ...attributes>
        <h3 class="review-item__aside-title">{{i18n "review.dsa.title"}}</h3>
        <p class="dsa-classification__status">
          {{#if (eq @classification.status "failed")}}
            {{i18n "review.statuses.dsa_failed.title"}}
          {{else}}
            {{i18n "review.statuses.dsa_classification.title"}}
          {{/if}}
        </p>
        {{#if this.showFailure}}
          <p class="dsa-classification__error" role="alert">
            {{@classification.error}}
          </p>
          <p>{{i18n
              (concat "review.dsa.rules." @classification.community_rule)
            }}</p>
          <p>{{i18n
              (concat "review.dsa.categories." @classification.category)
            }}</p>
          <div class="review-item__moderator-actions">
            <DButton
              class="btn-default"
              @action={{this.edit}}
              @disabled={{this.retrying}}
              @label="review.dsa.edit"
            />
            <DButton
              class="btn-primary"
              @action={{this.retry}}
              @disabled={{this.retrying}}
              @label="review.dsa.retry"
            />
          </div>
        {{else}}
          <Form @data={{this.formData}} @onSubmit={{this.save}} as |form|>
            <form.Field
              @name="community_rule"
              @title={{i18n "review.dsa.community_rule"}}
              @type="select"
              @validation="required"
              as |field|
            >
              <field.Control @format="full" as |select|>
                <select.Option @value="">{{i18n
                    "review.dsa.choose_rule"
                  }}</select.Option>
                {{#each @options.rules as |rule|}}
                  <select.Option @value={{rule}}>{{i18n
                      (concat "review.dsa.rules." rule)
                    }}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>
            <form.Field
              @name="category"
              @title={{i18n "review.dsa.category"}}
              @type="select"
              @validation="required"
              as |field|
            >
              <field.Control @format="full" as |select|>
                <select.Option @value="">{{i18n
                    "review.dsa.choose_category"
                  }}</select.Option>
                {{#each @options.categories as |category|}}
                  <select.Option @value={{category}}>{{i18n
                      (concat "review.dsa.categories." category)
                    }}</select.Option>
                {{/each}}
              </field.Control>
            </form.Field>
            <form.Submit @label="review.dsa.save" />
          </Form>
        {{/if}}
      </section>
    {{/unless}}
  </template>
}
