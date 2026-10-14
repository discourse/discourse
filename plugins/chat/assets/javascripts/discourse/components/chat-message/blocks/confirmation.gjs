import categoryColorVariable from "discourse/helpers/category-color-variable";
import ChatMessageText from "../../chat-message-text";
import Actions from "./actions";

function showBody(definition) {
  return definition.show_description !== false;
}

function showDescription(definition) {
  return (
    definition.show_description !== false ||
    definition.changes?.length ||
    definition.parameters?.length ||
    definition.cooked_error
  );
}

const Confirmation = <template>
  <section class="chat-confirmation">
    <div class="chat-confirmation__title">
      {{#if @definition.cooked_title}}
        <ChatMessageText
          @cooked={{@definition.cooked_title}}
          @decorate={{@decorate}}
        />
      {{else}}
        {{@definition.title}}
      {{/if}}
    </div>
    {{#if (showDescription @definition)}}
      <div class="chat-confirmation__description">
        {{#if @definition.changes.length}}
          {{#each @definition.changes as |change|}}
            <div class="chat-confirmation__change">
              <div
                class="chat-confirmation__change-label"
              >{{change.label}}</div>
              <div class="chat-confirmation__diff">
                <del class="chat-confirmation__before">
                  {{#if change.before_color}}
                    <span
                      aria-hidden="true"
                      class="chat-confirmation__color"
                      style={{categoryColorVariable change.before_color}}
                    ></span>
                  {{/if}}
                  <span
                    class="chat-confirmation__diff-value"
                  >{{change.before}}</span>
                </del>
                <span aria-hidden="true">→</span>
                <ins class="chat-confirmation__after">
                  {{#if change.after_color}}
                    <span
                      aria-hidden="true"
                      class="chat-confirmation__color"
                      style={{categoryColorVariable change.after_color}}
                    ></span>
                  {{/if}}
                  <span
                    class="chat-confirmation__diff-value"
                  >{{change.after}}</span>
                </ins>
              </div>
            </div>
          {{/each}}
        {{else if (showBody @definition)}}
          <div class="chat-confirmation__change">
            {{#if @definition.description_label}}
              <div
                class="chat-confirmation__change-label"
              >{{@definition.description_label}}</div>
            {{/if}}
            <ChatMessageText @cooked={{@cooked}} @decorate={{@decorate}} />
          </div>
        {{/if}}
        {{#if @definition.cooked_error}}
          <ChatMessageText
            @cooked={{@definition.cooked_error}}
            @decorate={{@decorate}}
          />
        {{/if}}
        {{#if @definition.parameters.length}}
          <dl class="chat-confirmation__parameters">
            {{#each @definition.parameters as |parameter|}}
              <dt><code>{{parameter.label}}</code></dt>
              <dd>
                {{#if parameter.color}}
                  <span
                    aria-hidden="true"
                    class="chat-confirmation__color"
                    style={{categoryColorVariable parameter.color}}
                  ></span>
                {{/if}}
                <span
                  class="chat-confirmation__parameter-value"
                >{{parameter.value}}</span>
              </dd>
            {{/each}}
          </dl>
        {{/if}}
      </div>
    {{/if}}
    <div class="chat-confirmation__footer">
      {{#if @definition.cooked_status}}
        <ChatMessageText
          @cooked={{@definition.cooked_status}}
          @decorate={{@decorate}}
        />
      {{else}}
        <ChatMessageText
          @cooked={{@definition.cooked_question}}
          @decorate={{@decorate}}
        />
        <Actions
          @createInteraction={{@createInteraction}}
          @definition={{@definition}}
        />
      {{/if}}
    </div>
  </section>
</template>;

export default Confirmation;
