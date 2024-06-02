import Component from "@glimmer/component";

export default class AdminConfigAreasBase extends Component {
  get primaryContentComponent() {
    throw new Error(
      "subclass of AdminConfigAreasBase must implement primaryContentComponent"
    );
  }

  get helpInsetComponent() {
    throw new Error(
      "subclass of AdminConfigAreasBase must implement helpInsetComponent"
    );
  }

  <template>
    <div class="admin-config-area">
      <div class="admin-config-area__primary-content">
        <this.primaryContentComponent />
      </div>
      <div class="admin-config-area__help-inset">
        <this.helpInsetComponent />
      </div>
    </div>
  </template>
}
