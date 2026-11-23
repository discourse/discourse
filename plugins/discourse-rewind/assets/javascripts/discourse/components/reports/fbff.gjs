import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import dBoundAvatarTemplate from "discourse/ui-kit/helpers/d-bound-avatar-template";
import { i18nForOwner } from "discourse/plugins/discourse-rewind/discourse/lib/rewind-i18n";

const Friend = <template>
  <figure class="rewind-fbff__person">
    <div class="rewind-frame">
      {{dBoundAvatarTemplate
        @friend.avatar_template
        "huge"
        (hash extraClasses="rewind-avatar" title=@friend.username)
      }}
    </div>
    <figcaption class="rewind-fbff__name">
      @{{@friend.username}}
    </figcaption>
  </figure>
</template>;

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
      <h2 class="rewind-report-title">{{this.titleText}}</h2>
      <div class="rewind-fbff">
        <Friend @friend={{@report.data.fbff}} />
        <div class="rewind-fbff__middle">
          <span class="rewind-fbff__heart"></span>
        </div>
        <Friend @friend={{@report.data.yourself}} />
      </div>
    </div>
  </template>
}
