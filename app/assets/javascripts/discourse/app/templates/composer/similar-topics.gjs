import RouteTemplate from 'ember-route-template'
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";
import { fn } from "@ember/helper";
import iN from "discourse/helpers/i18n";
import Topic from "discourse/components/search-menu/results/type/topic";
export default RouteTemplate(<template><ComposerTipCloseButton @action={{fn @controller.closeMessage @controller.message}} />

<h3>{{iN "composer.similar_topics"}}</h3>

<ul class="topics">
  {{#each @controller.message.similarTopics as |topic|}}
    <div class="similar-topic">
      <Topic @result={{topic}} @withTopicUrl={{true}} />
    </div>
  {{/each}}
</ul></template>)