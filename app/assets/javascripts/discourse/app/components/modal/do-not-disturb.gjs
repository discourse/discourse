import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import TapTile from "discourse/components/tap-tile";
import TapTileGrid from "discourse/components/tap-tile-grid";
import { extractError } from "discourse/lib/ajax-error";
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
        <TapTileGrid as |grid|>
          <TapTile
            @tileId="30"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.half_hour"}}
          </TapTile>
          <TapTile
            @tileId="60"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.one_hour"}}
          </TapTile>
          <TapTile
            @tileId="120"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.two_hours"}}
          </TapTile>
          <TapTile
            @tileId="tomorrow"
            @activeTile={{grid.activeTile}}
            @onChange={{this.saveDuration}}
            class="do-not-disturb-tile"
          >
            {{i18n "pause_notifications.options.tomorrow"}}
          </TapTile>
        </TapTileGrid>

        <DButton
          @action={{this.navigateToNotificationSchedule}}
          @label="pause_notifications.set_schedule"
        />
      </:body>
    </DModal>
  </template>
}
