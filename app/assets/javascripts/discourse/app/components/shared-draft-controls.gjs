/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";

@tagName("")
export default class SharedDraftControls extends Component {
  @service dialog;

  publishing = false;

  @discourseComputed("topic.destination_category_id")
  validCategory(destCatId) {
    return destCatId && destCatId !== this.site.shared_drafts_category_id;
  }

  @action
  updateDestinationCategory(categoryId) {
    return this.topic.updateDestinationCategory(categoryId);
  }

  @action
  publish() {
    this.dialog.yesNoConfirm({
      message: i18n("shared_drafts.confirm_publish"),
      didConfirm: () => {
        this.set("publishing", true);
        const destinationCategoryId = this.topic.destination_category_id;
        return this.topic
          .publish()
          .then(() => {
            this.topic.setProperties({
              category_id: destinationCategoryId,
              destination_category_id: undefined,
              is_shared_draft: false,
            });
          })
          .finally(() => {
            this.set("publishing", false);
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
            @value={{this.topic.destination_category_id}}
            @onChange={{this.updateDestinationCategory}}
          />
        </div>

        <div class="publish-field">
          {{#if this.validCategory}}
            <DButton
              @action={{this.publish}}
              @label="shared_drafts.publish"
              @icon="far-clipboard"
              class="btn-primary publish-shared-draft"
            />
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
