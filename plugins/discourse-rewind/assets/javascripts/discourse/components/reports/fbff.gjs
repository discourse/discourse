import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import avatar from "discourse/helpers/bound-avatar-template";
import getURL from "discourse/lib/get-url";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

export default class FBFF extends Component {
  get titleText() {
    return i18nForOwner(
      "discourse_rewind.reports.fbff.title",
      this.args.isOwnRewind,
      { username: this.args.user?.username }
    );
  }

  <template>
    <div class="rewind-report-page --fbff">
      <h2 class="rewind-report-title">
        {{this.titleText}}
      </h2>
      <div class="rewind-report-container">
        <div class="rewind-card">
          <div class="fbff-avatar-container">
            {{avatar
              @report.data.fbff.avatar_template
              "huge"
              (hash title=@report.data.fbff.username)
            }}
            <p class="fbff-avatar-name">@{{@report.data.fbff.username}}</p>
          </div>
          <div class="fbff-gif-container">
            <img
              class="fbff-gif"
              src={{getURL "/plugins/discourse-rewind/images/fbff.gif"}}
            />
          </div>
          <div class="fbff-avatar-container">
            {{avatar
              @report.data.yourself.avatar_template
              "huge"
              (hash title=@report.data.yourself.username)
            }}
            <p class="fbff-avatar-name">@{{@report.data.yourself.username}}</p>
          </div>
        </div>
      </div>
    </div>
  </template>
}
