/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class TapTileGrid extends Component {
  activeTile = null;

  <template>
    <div class="tap-tile-grid" ...attributes>
      {{yield (hash activeTile=this.activeTile)}}
    </div>
  </template>
}
