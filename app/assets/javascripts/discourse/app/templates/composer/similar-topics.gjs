import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import Topic from "discourse/components/search-menu/results/type/topic";
import { i18n } from "discourse-i18n";

export default RouteTemplate(
  <template>
    <ComposerTipCloseButton
      @action={{fn @controller.closeMessage @controller.message}}
    />

    <h3>{{i18n "composer.similar_topics"}}</h3>

    <ul class="topics">
      {{#each @controller.message.similarTopics as |topic|}}
        <div class="similar-topic">
          <Topic @result={{topic}} @withTopicUrl={{true}} />
        </div>
      {{/each}}
    </ul>
  </template>
);
