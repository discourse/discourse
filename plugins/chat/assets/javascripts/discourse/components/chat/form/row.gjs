import { LinkTo } from "@ember/routing";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

const ChatFormRow = <template>
  {{#if @route}}
    <LinkTo
      @route={{@route}}
      @models={{@routeModels}}
      class={{dConcatClass "chat-form__row -link" (if @separator "-separator")}}
    >
      <div class="chat-form__row-content">
        {{@label}}
        {{dIcon "chevron-right" class="chat-form__row-icon"}}
      </div>
    </LinkTo>
  {{else}}
    <div class={{dConcatClass "chat-form__row" (if @separator "-separator")}}>
      <div class="chat-form__row-content">
        {{#if @label}}
          <span class="chat-form__row-label">{{@label}}</span>
        {{/if}}

        {{#if (has-block)}}
          <span class="chat-form__row-label">
            {{yield}}
          </span>
        {{/if}}

        {{#if (has-block "action")}}
          <div class="chat-form__row-action">{{yield to="action"}}</div>
        {{/if}}
      </div>

      {{#if (has-block "description")}}
        <div class="chat-form__row-description">
          {{yield to="description"}}
        </div>
      {{/if}}
    </div>
  {{/if}}
</template>;

export default ChatFormRow;
