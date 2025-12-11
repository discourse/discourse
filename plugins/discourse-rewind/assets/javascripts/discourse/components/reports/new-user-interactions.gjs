import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class NewUserInteractions extends Component {
  get wavyWords() {
    const num = this.args.report.data.unique_new_users;
    const memberText = i18n(
      "discourse_rewind.reports.new_user_interactions.new_member",
      { count: num }
    );
    return memberText.split(" ").map((word) => word.split(""));
  }

  <template>
    <div class="rewind-report-page --new-user-interactions">
      <div class="wordart-container">
        <div class="wordart-text">
          {{i18n
            "discourse_rewind.reports.new_user_interactions.your_contributions_helped"
          }}
        </div>
        <div class="wordart-3d">
          {{#each this.wavyWords as |word|}}
            <span class="wordart-word">
              {{#each word as |char|}}
                <span class="wordart-letter">{{char}}</span>
              {{/each}}
            </span>
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
