import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DTapTile from "discourse/ui-kit/d-tap-tile";
import DTapTileGrid from "discourse/ui-kit/d-tap-tile-grid";
import { i18n } from "discourse-i18n";

export default class DoNotDisturb extends Component {
  @service currentUser;
  @service router;

  @tracked flash;

  @action
  async saveDuration(duration) {
    try {
      await this.currentUser.enterDoNotDisturbFor(duration);
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  @action
  navigateToNotificationSchedule() {
    this.router.transitionTo("preferences.notifications", this.currentUser);
    this.args.closeModal();
  }

  <template>
    <DModal
      @title={{i18n "pause_notifications.title"}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      class="do-not-disturb-modal"
    >
      <:body>
        <DTapTileGrid as |grid|>
          <DTapTile
            @tileId="30"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.half_hour"}}
          </DTapTile>
          <DTapTile
            @tileId="60"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.one_hour"}}
          </DTapTile>
          <DTapTile
            @tileId="120"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.two_hours"}}
          </DTapTile>
          <DTapTile
            @tileId="tomorrow"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.tomorrow"}}
          </DTapTile>
        </DTapTileGrid>

        <DButton
          @action={{this.navigateToNotificationSchedule}}
          @label="pause_notifications.set_schedule"
        />
      </:body>
    </DModal>
  </template>
}
