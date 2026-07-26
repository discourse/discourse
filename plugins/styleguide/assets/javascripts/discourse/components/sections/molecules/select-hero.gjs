import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import { TAGS } from "../../../lib/select-fixtures";

const NOTIFICATION_LEVELS = [
  { id: "watching", icon: "eye", key: "watching" },
  { id: "tracking", icon: "circle", key: "tracking" },
  { id: "regular", icon: "bell", key: "normal" },
  { id: "muted", icon: "bell-slash", key: "muted" },
];

/**
 * The page's opening statement: three selects side by side at real composer density.
 *
 * Every other example on this page shows one control alone in a box, which is the arrangement
 * least able to reveal whether the component is a coherent system. Sitting three instances on
 * one row is where trigger height, baseline alignment, icon optical size and chip wrapping are
 * actually judged — and it is the only place a reader sees the component doing a whole job
 * rather than demonstrating an argument.
 *
 * All three rest filled, because a filled trigger is what a user sees almost all of the time.
 */
export default class SelectHero extends Component {
  @tracked categoryValue = null;
  @tracked notificationValue = "watching";
  @tracked tagValue = ["design-system", "accessibility"];

  tags = TAGS;

  get categories() {
    return this.args.categories ?? [];
  }

  get notificationLevels() {
    return NOTIFICATION_LEVELS.map((level) => ({
      ...level,
      name: i18n(
        `styleguide.sections.select.showcases.notifications.${level.key}`
      ),
    }));
  }

  @action
  updateCategory(value) {
    this.categoryValue = value;
  }

  @action
  updateNotification(value) {
    this.notificationValue = value;
  }

  @action
  updateTags(value) {
    this.tagValue = value;
  }

  <template>
    <section class="select-hero" data-test-select-hero>
      <p class="select-hero__caption">
        {{i18n "styleguide.sections.select.hero.caption"}}
      </p>

      <div class="select-hero__row">
        <label class="select-hero__field">
          <span class="select-hero__label">
            {{i18n "styleguide.sections.select.hero.category"}}
          </span>
          <DSelect
            @identifier="sg-hero-category"
            @items={{this.categories}}
            @value={{this.categoryValue}}
            @onChange={{this.updateCategory}}
            @valueField="slug"
            @variant="button"
            @placeholder={{i18n "styleguide.sections.select.hero.category"}}
          >
            <:selection as |item|>{{dCategoryBadge item}}</:selection>
            <:item as |item|>{{dCategoryBadge item}}</:item>
          </DSelect>
        </label>

        <label class="select-hero__field select-hero__field--wide">
          <span class="select-hero__label">
            {{i18n "styleguide.sections.select.hero.tags"}}
          </span>
          <DSelect
            @identifier="sg-hero-tags"
            @items={{this.tags}}
            @multiple={{true}}
            @value={{this.tagValue}}
            @onChange={{this.updateTags}}
            @valueField="slug"
            @labelField="label"
            @placeholder={{i18n "styleguide.sections.select.hero.tags"}}
          >
            <:selection as |item|>{{item.label}}</:selection>
            <:item as |item|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon "tag"}}
                <span class="select-examples__primary">{{item.label}}</span>
                <span class="select-examples__meta">{{item.count}}</span>
              </span>
            </:item>
          </DSelect>
        </label>

        <label class="select-hero__field">
          <span class="select-hero__label">
            {{i18n "styleguide.sections.select.hero.notifications"}}
          </span>
          <DSelect
            @identifier="sg-hero-notifications"
            @items={{this.notificationLevels}}
            @value={{this.notificationValue}}
            @onChange={{this.updateNotification}}
            @variant="static"
          >
            <:selection as |item|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon item.icon}}{{item.name}}
              </span>
            </:selection>
            <:item as |item|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon item.icon}}{{item.name}}
              </span>
            </:item>
          </DSelect>
        </label>
      </div>
    </section>
  </template>
}
