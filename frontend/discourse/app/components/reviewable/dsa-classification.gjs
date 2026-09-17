import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import {
  dsaCategoryLabel,
  dsaClassificationSummary,
  dsaKeywordLabel,
  dsaLegalBasisLabel,
  ILLEGAL_CONTENT,
  OTHER_KEYWORD,
} from "discourse/lib/dsa-classification";
import { manuallyTrack } from "discourse/lib/tracked-tools";
import { eq, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ReviewableDsaClassification extends Component {
  @service site;
  @service store;

  @cached
  get state() {
    // reading the argument is what ties this cache to a single reviewable
    manuallyTrack(this.args.reviewable);

    // Content incompatible with the terms of service is already classified, but a keyword
    // can still be added.
    return trackedObject({ editing: !this.canCancel });
  }

  get illegal() {
    return this.args.reviewable.legal_basis === ILLEGAL_CONTENT;
  }

  get categories() {
    return this.site.dsa_taxonomy[this.args.reviewable.legal_basis];
  }

  get categoryCodes() {
    return Object.keys(this.categories);
  }

  get canCancel() {
    const { reviewable } = this.args;
    return this.illegal
      ? !!reviewable.dsa_category
      : !!reviewable.dsa_subcategory;
  }

  get summary() {
    return dsaClassificationSummary(this.args.reviewable);
  }

  @cached
  get formData() {
    const { reviewable } = this.args;

    return {
      dsa_category:
        reviewable.dsa_category ??
        (this.illegal ? undefined : this.categoryCodes[0]),
      dsa_subcategory: reviewable.dsa_subcategory,
      dsa_subcategory_other: reviewable.dsa_subcategory_other,
    };
  }

  @bind
  keywordsFor(category) {
    return (category && this.categories[category]) || [];
  }

  @action
  edit() {
    this.state.editing = true;
  }

  @action
  cancel() {
    this.state.editing = false;
  }

  @action
  onCategorySet(value, { set }) {
    set("dsa_category", value);
    set("dsa_subcategory", undefined);
  }

  @action
  async save(data) {
    const { reviewable } = this.args;

    try {
      await ajax(`/review/${reviewable.id}/dsa-classification`, {
        type: "PUT",
        data,
      });
      await this.store.find("reviewable", reviewable.id);
      this.state.editing = false;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="reviewable-dsa-classification">
      <h3 class="review-item__aside-title">
        {{i18n "review.dsa.title"}}
      </h3>

      {{#if this.state.editing}}
        <Form
          class="reviewable-dsa-classification__form"
          @data={{this.formData}}
          @onSubmit={{this.save}}
          as |form data|
        >
          <form.Field
            @disabled={{not this.illegal}}
            @format="full"
            @name="dsa_category"
            @onSet={{this.onCategorySet}}
            @title={{i18n "review.dsa.category"}}
            @type="select"
            @validation="required"
            as |field|
          >
            <field.Control as |select|>
              {{#each this.categoryCodes as |code|}}
                <select.Option @value={{code}}>
                  {{#if this.illegal}}
                    {{dsaCategoryLabel code}}
                  {{else}}
                    {{dsaLegalBasisLabel @reviewable.legal_basis}}
                  {{/if}}
                </select.Option>
              {{/each}}
            </field.Control>
          </form.Field>

          {{#let (this.keywordsFor data.dsa_category) as |keywords|}}
            {{#if keywords.length}}
              <form.Field
                @format="full"
                @name="dsa_subcategory"
                @title={{i18n "review.dsa.subcategory"}}
                @type="select"
                as |field|
              >
                <field.Control as |select|>
                  {{#each keywords as |code|}}
                    <select.Option @value={{code}}>
                      {{dsaKeywordLabel code}}
                    </select.Option>
                  {{/each}}
                </field.Control>
              </form.Field>
            {{/if}}
          {{/let}}

          {{#if (eq data.dsa_subcategory OTHER_KEYWORD)}}
            <form.Field
              @format="full"
              @name="dsa_subcategory_other"
              @title={{i18n "review.dsa.subcategory_other"}}
              @type="textarea"
              @validation="required:trim|length:1,500"
              as |field|
            >
              <field.Control @height={{80}} />
            </form.Field>
          {{/if}}

          <form.Actions>
            <form.Submit
              class="btn-primary reviewable-dsa-classification__save"
              @label="review.dsa.save"
            />
            {{#if this.canCancel}}
              <form.Button
                class="btn-transparent reviewable-dsa-classification__cancel"
                @action={{this.cancel}}
                @label="review.cancel"
              />
            {{/if}}
          </form.Actions>
        </Form>
      {{else}}
        <p class="reviewable-dsa-classification__summary">
          {{this.summary}}
        </p>
        <DButton
          class="btn-default btn-small reviewable-dsa-classification__edit"
          @action={{this.edit}}
          @label="review.dsa.edit"
        />
      {{/if}}
    </div>
  </template>
}
