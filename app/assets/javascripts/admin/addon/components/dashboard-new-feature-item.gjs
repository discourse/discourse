import Component from "@glimmer/component";
import CookText from "discourse/components/cook-text";

export default class DashboardNewFeatureItem extends Component {
  <template>
    <div class="admin-new-feature-item">
      <div class="admin-new-feature-item__content">
        <div class="admin-new-feature-item__header">
          <h3>
            {{#if @item.link}}
              <a
                href={{@item.link}}
                target="_blank"
                rel="noopener noreferrer"
              >{{@item.title}}</a>
            {{else}}
              {{@item.title}}
            {{/if}}
          </h3>
          {{#if @item.emoji}}
            <div
              class="admin-new-feature-item__new-feature-emoji"
            >{{@item.emoji}}</div>
          {{/if}}
        </div>
        {{#if @item.screenshot_url}}
          <img
            src={{@item.screenshot_url}}
            class="admin-new-feature-item__screenshot"
            alt={{@item.title}}
          />
        {{/if}}
        <div class="admin-new-feature-item__feature-description">
          <CookText @rawText={{@item.description}} />
        </div>
      </div>
    </div>
  </template>
}
