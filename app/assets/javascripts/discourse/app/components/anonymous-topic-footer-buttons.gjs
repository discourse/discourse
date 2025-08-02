import Component from "@ember/component";
import { concat } from "@ember/helper";
import { computed } from "@ember/object";
import { attributeBindings } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import concatClass from "discourse/helpers/concat-class";
import routeAction from "discourse/helpers/route-action";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";

@attributeBindings("role")
export default class AnonymousTopicFooterButtons extends Component {
  elementId = "topic-footer-buttons";
  role = "region";

  @getTopicFooterButtons() allButtons;

  @computed("allButtons.[]")
  get buttons() {
    return this.allButtons
      .filterBy("anonymousOnly", true)
      .sortBy("priority")
      .reverse();
  }

  <template>
    <div class="topic-footer-main-buttons">
      {{#each this.buttons as |button|}}
        <DButton
          @action={{button.action}}
          @icon={{button.icon}}
          @translatedLabel={{button.label}}
          @translatedTitle={{button.title}}
          @translatedAriaLabel={{button.ariaLabel}}
          @disabled={{button.disabled}}
          id={{concat "topic-footer-button-" button.id}}
          class={{concatClass
            "btn-default"
            "topic-footer-button"
            button.classNames
          }}
        />
      {{/each}}
      <DButton
        @icon="reply"
        @action={{routeAction "showLogin"}}
        @label="topic.reply.title"
        class="btn-primary"
      />
    </div>
  </template>
}
