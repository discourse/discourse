import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import DModalCancel from "discourse/components/d-modal-cancel";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class Reseed extends Component {
  @service dialog;

  @tracked loading = true;
  @tracked reseeding = false;
  @tracked categories = null;
  @tracked topics = null;
  @tracked flash;

  constructor() {
    super(...arguments);
    this.loadReseed();
  }

  @action
  async loadReseed() {
    try {
      const result = await ajax("/admin/customize/reseed");
      this.categories = result.categories;
      this.topics = result.topics;
    } finally {
      this.loading = false;
    }
  }

  _extractSelectedIds(items) {
    return items.filter((item) => item.selected).map((item) => item.id);
  }

  @action
  async reseed() {
    try {
      this.reseeding = true;
      await ajax("/admin/customize/reseed", {
        data: {
          category_ids: this._extractSelectedIds(this.categories),
          topic_ids: this._extractSelectedIds(this.topics),
        },
        type: "POST",
      });

      this.flash = null;
      this.args.closeModal();
    } catch {
      this.flash = i18n("generic_error");
    } finally {
      this.reseeding = false;
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "admin.reseed.modal.title"}}
      @subtitle={{i18n "admin.reseed.modal.subtitle"}}
      class="reseed-modal"
      @flash={{this.flash}}
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.categories}}
            <fieldset>
              <legend class="options-group-title">
                {{i18n "admin.reseed.modal.categories"}}
              </legend>
              {{#each this.categories as |category|}}
                <label>
                  <Input
                    class="option"
                    @type="checkbox"
                    @checked={{category.selected}}
                  />
                  <span>{{category.name}}</span>
                </label>
              {{/each}}
            </fieldset>
          {{/if}}
          <br />
          {{#if this.topics}}
            <fieldset>
              <legend class="options-group-title">
                {{i18n "admin.reseed.modal.topics"}}
              </legend>
              {{#each this.topics as |topic|}}
                <label>
                  <Input
                    class="option"
                    @type="checkbox"
                    @checked={{topic.selected}}
                  />
                  <span>{{topic.name}}</span>
                </label>
              {{/each}}
            </fieldset>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          @action={{this.reseed}}
          @label="admin.reseed.modal.replace"
          @isLoading={{this.reseeding}}
          class="btn-danger"
        />

        {{#unless this.reseeding}}
          <DModalCancel @close={{@closeModal}} />
        {{/unless}}
      </:footer>
    </DModal>
  </template>
}
