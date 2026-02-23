/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
export default class PostVotingCategorySettings extends Component {
  <template>
    <div
      class="category-custom-settings-outlet post-voting-category-settings"
      ...attributes
    >
      <h3>{{i18n "category.post_voting_settings_heading"}}</h3>
      <section class="field">
        <label>
          <Input
            id="create-as-post-voting-default"
            @type="checkbox"
            @checked={{this.category.custom_fields.create_as_post_voting_default}}
          />
          {{i18n "category.create_as_post_voting_default"}}
        </label>
        <label>
          <Input
            id="only-post-voting-in-this-category"
            @type="checkbox"
            @checked={{this.category.custom_fields.only_post_voting_in_this_category}}
          />
          {{i18n "category.only_post_voting_in_this_category"}}
        </label>
      </section>
    </div>
  </template>
}
