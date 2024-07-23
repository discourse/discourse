import { and, not } from "truth-helpers";
import CookText from "discourse/components/cook-text";
import i18n from "discourse-common/helpers/i18n";

const DashboardNewFeatureItem = <template>
  <div class="admin-new-feature-item">
    <div class="admin-new-feature-item__content">
      <div class="admin-new-feature-item__header">
        {{#if (and @item.emoji (not @item.screenshot_url))}}
          <div class="admin-new-feature-item__new-feature-emoji">
            {{@item.emoji}}
          </div>
        {{/if}}
        <h3>
          {{@item.title}}
        </h3>
        {{#if @item.discourse_version}}
          <div class="admin-new-feature-item__new-feature-version">
            {{@item.discourse_version}}
          </div>
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

        {{#if @item.link}}
          <a
            href={{@item.link}}
            target="_blank"
            rel="noopener noreferrer"
            class="admin-new-feature-item__learn-more"
          >
            {{i18n "admin.dashboard.new_features.learn_more"}}
          </a>
        {{/if}}
      </div>
    </div>
  </div>
</template>;

export default DashboardNewFeatureItem;
