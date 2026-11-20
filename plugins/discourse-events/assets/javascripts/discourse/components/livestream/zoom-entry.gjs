import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import {
  shouldIgnoreZoomTimeframe,
  zoomRouteOptions,
} from "../../lib/livestream-utils.js";
import promptAnonymousLivestreamJoin from "../../lib/prompt-anonymous-livestream-join.js";

export default class LivestreamZoomEntry extends Component {
  @service currentUser;
  @service router;
  @service siteSettings;

  get topic() {
    return this.args.event.post.topic;
  }

  get shouldRender() {
    return (
      this.siteSettings.livestream_zoom_enabled &&
      this.args.event.livestreamChatChannelId &&
      !this.args.event.pastEventTimeframe
    );
  }

  get canJoinNow() {
    return (
      this.args.event.currentlyWithinEventTimeframe ||
      shouldIgnoreZoomTimeframe(this.currentUser, this.args.event)
    );
  }

  get joinDisabled() {
    return !this.canJoinNow;
  }

  // A disabled anchor is still followable, so only link when joining is possible.
  get joinHref() {
    if (!this.canJoinNow || !this.currentUser) {
      return null;
    }

    return this.router.urlFor(
      "topic-zoom",
      this.topic.slug,
      this.topic.id,
      zoomRouteOptions(this.currentUser, this.args.event)
    );
  }

  @action
  joinZoom(event) {
    if (!this.currentUser) {
      event.preventDefault();
      if (this.args.event.allowAnonymousLivestream) {
        return promptAnonymousLivestreamJoin(this, this.args.event);
      }

      getOwner(this).lookup("route:application").send("showCreateAccount");
      return;
    }

    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    this.router.transitionTo(
      "topic-zoom",
      this.topic.slug,
      this.topic.id,
      zoomRouteOptions(this.currentUser, this.args.event)
    );
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-calendar-livestream-zoom-entry">
        <div class="discourse-calendar-livestream-zoom-entry__actions">
          <DButton
            class="discourse-calendar-livestream-zoom-entry__join btn-primary"
            @disabled={{this.joinDisabled}}
            @href={{this.joinHref}}
            @icon="video"
            @label="discourse_events.livestream.zoom.join"
            {{on "click" this.joinZoom}}
          />

          <p class="discourse-calendar-livestream-zoom-entry__waiting">
            {{i18n "discourse_events.livestream.zoom.too_early"}}
          </p>
        </div>
      </div>
    {{/if}}
  </template>
}
