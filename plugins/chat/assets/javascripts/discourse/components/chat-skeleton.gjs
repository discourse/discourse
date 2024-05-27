import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class ChatSkeleton extends Component {
  get placeholders() {
    return Array.from({ length: 15 }, () => {
      return {
        image: this.#randomIntFromInterval(1, 10) === 5,
        rows: Array.from({ length: this.#randomIntFromInterval(1, 5) }, () => {
          return htmlSafe(`width: ${this.#randomIntFromInterval(20, 95)}%`);
        }),
        reactions: Array.from({ length: this.#randomIntFromInterval(0, 3) }),
      };
    });
  }

  #randomIntFromInterval(min, max) {
    return Math.floor(Math.random() * (max - min + 1) + min);
  }

  <template>
    <div class="chat-skeleton -animation">
      {{#each this.placeholders as |placeholder|}}
        <div class="chat-skeleton__body">
          <div class="chat-skeleton__message">
            <div class="chat-skeleton__message-avatar"></div>
            <div class="chat-skeleton__message-poster"></div>
            <div class="chat-skeleton__message-content">
              {{#if placeholder.image}}
                <div class="chat-skeleton__message-img"></div>
              {{/if}}

              <div class="chat-skeleton__message-text">
                {{#each placeholder.rows as |row|}}
                  <div class="chat-skeleton__message-msg" style={{row}}></div>
                {{/each}}
              </div>

              {{#if placeholder.reactions}}
                <div class="chat-skeleton__message-reactions">
                  {{#each placeholder.reactions}}
                    <div class="chat-skeleton__message-reaction"></div>
                  {{/each}}
                </div>
              {{/if}}
            </div>
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
