import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class SharedDraftControls extends Component {
  @service dialog;
  @service site;

  @tracked publishing = false;

  // `destination_category_id` is a plain field on the topic model, so it is only tracked
  // when read through `get`.
  get validCategory() {
    if (!this.args.topic) {
      return false;
    }

    const destinationCategoryId = get(
      this.args.topic,
      "destination_category_id"
    );

    return (
      destinationCategoryId &&
      destinationCategoryId !== this.site.shared_drafts_category_id
    );
  }

  @action
  updateDestinationCategory(categoryId) {
    return this.args.topic.updateDestinationCategory(categoryId);
  }

  @action
  publish() {
    this.dialog.yesNoConfirm({
      message: i18n("shared_drafts.confirm_publish"),
      didConfirm: () => {
        this.publishing = true;
        const destinationCategoryId = this.args.topic.destination_category_id;
        return this.args.topic
          .publish()
          .then(() => {
            this.args.topic.setProperties({
              category_id: destinationCategoryId,
              destination_category_id: undefined,
              is_shared_draft: false,
            });
          })
          .finally(() => {
            this.publishing = false;
          });
      },
    });
  }

  <template>
    <div class="shared-draft-controls">
      {{#if this.publishing}}
        {{i18n "shared_drafts.publishing"}}
      {{else}}
        {{i18n "shared_drafts.notice"}}

        <div class="publish-field">
          <label>{{i18n "shared_drafts.destination_category"}}</label>
          <CategoryChooser
            @onChange={{this.updateDestinationCategory}}
            @value={{@topic.destination_category_id}}
          />
        </div>

        <div class="publish-field">
          {{#if this.validCategory}}
            <DButton
              class="btn-primary publish-shared-draft"
              @action={{this.publish}}
              @icon="far-clipboard"
              @label="shared_drafts.publish"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
