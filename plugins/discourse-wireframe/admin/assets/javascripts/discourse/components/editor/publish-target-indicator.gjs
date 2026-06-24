// @ts-check
import Component from "@glimmer/component";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

/**
 * The toolbar chip that names where this session's changes will publish, and
 * opens the publish review surface when clicked. Before anything is edited it
 * names the active theme (the prospective target); once outlets are edited it
 * reflects their actual owner themes — a single theme by name, or a count when
 * the edits span several. A warning glyph appears when any target can't be
 * published to directly (a core or Git theme), nudging the author into the drawer
 * to set up a companion.
 */
export default class PublishTargetIndicator extends Component {
  @service wireframe;

  get targets() {
    return this.wireframe.publishTargets;
  }

  /**
   * The single target to name, or null when several themes are involved. Falls
   * back to the active theme when nothing is edited yet.
   *
   * @returns {Object|null}
   */
  get singleTarget() {
    if (this.targets.length === 1) {
      return this.targets[0];
    }
    if (this.targets.length === 0) {
      return this.wireframe.activeThemeTarget;
    }
    return null;
  }

  /** Whether there's anything to show (a resolvable target). */
  get hasTarget() {
    return this.targets.length > 0 || this.wireframe.activeThemeTarget != null;
  }

  /** Whether any target can't be published to directly. */
  get hasBlocked() {
    if (this.singleTarget) {
      return !this.singleTarget.publishable;
    }
    return this.targets.some((group) => !group.publishable);
  }

  get label() {
    if (this.singleTarget) {
      return i18n("wireframe.review.publishing_to_one", {
        theme:
          this.singleTarget.themeName ?? i18n("wireframe.review.this_theme"),
      });
    }
    return i18n("wireframe.review.publishing_to_many", {
      count: this.targets.length,
    });
  }

  <template>
    {{#if this.hasTarget}}
      <DButton
        class={{dConcatClass
          "btn-flat wireframe-target-indicator"
          (if this.hasBlocked "--blocked")
        }}
        @icon={{if this.hasBlocked "triangle-exclamation" "cloud-arrow-up"}}
        @translatedLabel={{this.label}}
        @action={{this.wireframe.openReviewDrawer}}
      />
    {{/if}}
  </template>
}
