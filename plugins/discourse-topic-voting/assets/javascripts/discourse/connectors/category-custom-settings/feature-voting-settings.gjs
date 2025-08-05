/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { classNames, tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
@classNames("category-custom-settings-outlet", "feature-voting-settings")
export default class FeatureVotingSettings extends Component {
  <template>
    <h3>{{i18n "topic_voting.title"}}</h3>
    <section class="field">
      <div class="enable-topic-voting">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{this.category.custom_fields.enable_topic_voting}}
          />
          {{i18n "topic_voting.allow_topic_voting"}}
        </label>
      </div>
    </section>
  </template>
}
