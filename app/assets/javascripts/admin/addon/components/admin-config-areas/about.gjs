import Component from "@glimmer/component";
import AdminConfigAreasBase from "./base";

export default class AdminConfigAreasAbout extends AdminConfigAreasBase {
  primaryContentComponent = class extends Component {
    <template>
      Primary Content
    </template>
  };
  helpInsetComponent = class extends Component {
    <template>
      Help Inset
    </template>
  };
}
