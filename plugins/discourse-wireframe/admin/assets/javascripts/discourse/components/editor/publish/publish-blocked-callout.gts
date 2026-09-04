import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import WireframePublishTargetService, {
  type ActiveThemeTarget,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";
import type WireframeStagingService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-staging";

/**
 * A one-time inline notice shown beneath the toolbar when the active theme can't
 * be published to directly (a core or Git theme). It explains why and offers a
 * shortcut into the review surface to set up a companion component, plus a
 * dismiss for the rest of the session. Stays out of the way in the common case —
 * it renders nothing when the active theme is directly publishable.
 */
export default class PublishBlockedCallout extends Component {
  /** Owns the review drawer and publish-target resolution state. */
  @service declare wireframeStaging: WireframeStagingService;
  /** Resolves the active theme's publishability. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** Whether the callout was dismissed for this component lifetime. */
  @tracked dismissed = false;

  /** Active theme target described by the callout. */
  get target(): ActiveThemeTarget | null {
    return this.wireframePublishTarget.activeThemeTarget;
  }

  /** Whether a blocked target should currently be explained. */
  get isVisible(): boolean {
    return (
      !this.dismissed &&
      !this.wireframeStaging.publishTargetResolving &&
      this.target != null &&
      !this.target.publishable
    );
  }

  /** Dismisses the callout for this component lifetime. */
  @action
  dismiss(): void {
    this.dismissed = true;
  }

  <template>
    {{#if this.isVisible}}
      <div class="wireframe-blocked-callout" role="status">
        <span class="wireframe-blocked-callout__icon">
          {{dIcon "circle-info"}}
        </span>
        <span class="wireframe-blocked-callout__message">
          {{#if this.target.isSystem}}
            {{i18n "wireframe.outlet.system_notice"}}
          {{else}}
            {{i18n "wireframe.outlet.git_notice"}}
          {{/if}}
        </span>
        <DButton
          class="btn-primary btn-small wireframe-blocked-callout__setup"
          @label="wireframe.review.set_up"
          @action={{this.wireframeStaging.openReviewDrawer}}
        />
        <DButton
          class="btn-flat btn-small wireframe-blocked-callout__dismiss"
          @icon="xmark"
          @ariaLabel="wireframe.review.dismiss"
          @action={{this.dismiss}}
        />
      </div>
    {{/if}}
  </template>
}
