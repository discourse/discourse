import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

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
      // TODO (martin) showzoom is for testing only, remove before merge
      new URLSearchParams(window.location.search).get("showzoom")
    );
  }

  get joinDisabled() {
    return !this.canJoinNow;
  }

  // A `disabled` anchor is still followable, and the meeting has nothing to
  // show an anonymous user, so the button only carries a link once it leads
  // somewhere: everything else is left to the click.
  get joinHref() {
    if (!this.canJoinNow || !this.currentUser) {
      return null;
    }

    return this.router.urlFor("topic-zoom", this.topic.slug, this.topic.id);
  }

  @action
  joinZoom(event) {
    if (!this.currentUser) {
      event.preventDefault();
      getOwner(this).lookup("route:application").send("showCreateAccount");
      return;
    }

    if (wantsNewWindow(event)) {
      return;
    }

    event.preventDefault();
    this.router.transitionTo("topic-zoom", this.topic.slug, this.topic.id);
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-calendar-livestream-zoom-entry">
        <div class="discourse-calendar-livestream-zoom-entry__actions">
          <DButton
            @href={{this.joinHref}}
            @label="discourse_calendar.livestream.zoom.join"
            @icon="video"
            class="discourse-calendar-livestream-zoom-entry__join btn-primary"
            @disabled={{this.joinDisabled}}
            {{on "click" this.joinZoom}}
          />

          {{#unless this.canJoinNow}}
            <p class="discourse-calendar-livestream-zoom-entry__waiting">
              {{i18n "discourse_calendar.livestream.zoom.too_early"}}
            </p>
          {{/unless}}
        </div>
      </div>
    {{/if}}
  </template>
}
