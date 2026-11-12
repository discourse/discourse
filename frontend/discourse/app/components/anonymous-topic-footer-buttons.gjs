/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { concat } from "@ember/helper";
import { compare } from "@ember/utils";
import { tagName } from "@ember-decorators/component";
import routeAction from "discourse/helpers/route-action";
import { getTopicFooterButtons } from "discourse/lib/register-topic-footer-button";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

@tagName("")
export default class AnonymousTopicFooterButtons extends Component {
  get allButtons() {
    return getTopicFooterButtons(this);
  }

  get buttons() {
    return (
      this.allButtons
        .filter((button) => button.anonymousOnly === true)
        .sort((a, b) => compare(a?.priority, b?.priority))
        // Reversing the array is necessary because when priorities are not set,
        // we want to show the most recently added item first
        .reverse()
    );
  }

  <template>
    <div id="topic-footer-buttons" role="region" ...attributes>
      <div class="topic-footer-main-buttons">
        {{#each this.buttons key="id" as |button|}}
          <DButton
            class={{dConcatClass
              "btn-default"
              "topic-footer-button"
              button.classNames
            }}
            id={{concat "topic-footer-button-" button.id}}
            @action={{button.action}}
            @disabled={{button.disabled}}
            @icon={{button.icon}}
            @translatedAriaLabel={{button.ariaLabel}}
            @translatedLabel={{button.label}}
            @translatedTitle={{button.title}}
          />
        {{/each}}
        <DButton
          class="btn-primary"
          @action={{routeAction "showLogin"}}
          @icon="reply"
          @label="topic.reply.title"
        />
      </div>
    </div>
  </template>
}
