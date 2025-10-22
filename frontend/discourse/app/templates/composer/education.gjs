import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import RouteTemplate from "ember-route-template";
import ComposerTipCloseButton from "discourse/components/composer-tip-close-button";

export default RouteTemplate(
  <template>
    <ComposerTipCloseButton
      @action={{fn @controller.closeMessage @controller.message}}
    />

    {{#if @controller.message.title}}
      <h3>{{@controller.message.title}}</h3>
    {{/if}}

    {{htmlSafe @controller.message.body}}
  </template>
);
