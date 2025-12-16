import { hash } from "@ember/helper";
import avatar from "discourse/helpers/bound-avatar-template";
import getURL from "discourse/lib/get-url";
import { i18n } from "discourse-i18n";

const FBFF = <template>
  <div class="rewind-report-page --fbff">
    <h2 class="rewind-report-title">
      {{i18n "discourse_rewind.reports.fbff.title"}}
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
</template>;

export default FBFF;
