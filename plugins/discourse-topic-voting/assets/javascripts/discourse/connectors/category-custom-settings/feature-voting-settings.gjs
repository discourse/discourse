import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { i18n } from "discourse-i18n";

export default class FeatureVotingSettings extends Component {
  static shouldRender(args, context) {
    return !context.siteSettings.enable_simplified_category_creation;
  }

  <template>
    <section class="field">
      <h3>{{i18n "topic_voting.title"}}</h3>
      <div class="enable-topic-voting">
        <label class="checkbox-label">
          <Input
            @type="checkbox"
            @checked={{@outletArgs.category.custom_fields.enable_topic_voting}}
          />
          {{i18n "topic_voting.allow_topic_voting"}}
        </label>
      </div>
    </section>
  </template>
}
