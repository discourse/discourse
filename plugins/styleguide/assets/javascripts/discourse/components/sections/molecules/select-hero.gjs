import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dCategoryBadge from "discourse/ui-kit/helpers/d-category-badge";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import DSelect from "discourse/ui-kit/select/d-select";
import { i18n } from "discourse-i18n";
import {
  categories,
  notificationLevels,
  TAGS,
} from "../../../lib/select-fixtures";

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
  @service store;

  @tracked categoryValue = "feature-requests";
  @tracked notificationValue = "watching";
  @tracked tagValue = ["theming", "accessibility"];

  tags = TAGS;

  @cached
  get categories() {
    return categories(this.store);
  }

  get notificationLevels() {
    return notificationLevels();
  }

  get tagItems() {
    return this.tags.map((tag) => ({
      ...tag,
      // Never the bare number: a trailing "12483" would be announced as part of the option's
      // name, so the row would read "design-system 12483".
      countLabel: i18n("styleguide.sections.select.hero.tag_topics", {
        count: tag.count,
      }),
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

      {{! Plain divs, never labels. A label element forwards every click inside it to its first
      labelable descendant — and a chip's remove button is labelable, so wrapping a multi-select
      in one made clicking anywhere in the field (the caret included) delete the first chip. The
      accessible name comes from the label argument instead, matching the visible text. }}
      <div class="select-hero__row">
        <div class="select-hero__field">
          <span class="select-hero__label" aria-hidden="true">
            {{i18n "styleguide.sections.select.hero.category"}}
          </span>
          <DSelect
            @identifier="sg-hero-category"
            @items={{this.categories}}
            @value={{this.categoryValue}}
            @onChange={{this.updateCategory}}
            @valueField="slug"
            @label={{i18n "styleguide.sections.select.hero.category"}}
            @placeholder={{i18n "styleguide.sections.select.hero.category"}}
          >
            {{! A category is a badge, not a string — no argument can express it. }}
            <:selection as |item|>{{dCategoryBadge item}}</:selection>
            <:item as |item|>{{dCategoryBadge item}}</:item>
          </DSelect>
        </div>

        <div class="select-hero__field select-hero__field--wide">
          <span class="select-hero__label" aria-hidden="true">
            {{i18n "styleguide.sections.select.hero.tags"}}
          </span>
          <DSelect
            @label={{i18n "styleguide.sections.select.hero.tags"}}
            @identifier="sg-hero-tags"
            @items={{this.tagItems}}
            @multiple={{true}}
            @value={{this.tagValue}}
            @onChange={{this.updateTags}}
            @valueField="slug"
            @labelField="label"
            @placeholder={{i18n "styleguide.sections.select.hero.tags"}}
          >
            {{! No selection block: the chip is a tag name, which is exactly the default. }}
            <:item as |item|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon "tag"}}
                <span class="select-examples__primary">{{item.label}}</span>
                <span class="select-examples__meta">{{item.countLabel}}</span>
              </span>
            </:item>
          </DSelect>
        </div>

        <div class="select-hero__field">
          <span class="select-hero__label" aria-hidden="true">
            {{i18n "styleguide.sections.select.hero.notifications"}}
          </span>
          <DSelect
            @label={{i18n "styleguide.sections.select.hero.notifications"}}
            @identifier="sg-hero-notifications"
            @items={{this.notificationLevels}}
            @value={{this.notificationValue}}
            @onChange={{this.updateNotification}}
            @valueField="level"
            @labelField="title"
            @variant="static"
          >
            {{! The icon is how a level is recognised at a glance; it is the same in both
            surfaces because both are a single line here. }}
            <:selection as |item|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon item.icon}}{{item.title}}
              </span>
            </:selection>
            <:item as |item|>
              <span class="select-examples__row select-examples__row--glyph">
                {{dIcon item.icon}}{{item.title}}
              </span>
            </:item>
          </DSelect>
        </div>
      </div>
    </section>
  </template>
}
