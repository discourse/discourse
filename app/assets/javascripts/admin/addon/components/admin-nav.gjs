import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class AdminNav extends Component {
  <template>
    <div class="admin-controls">
      <nav>
        <ul class="nav nav-pills">
          {{yield}}
        </ul>
      </nav>
    </div>
  </template>
}
