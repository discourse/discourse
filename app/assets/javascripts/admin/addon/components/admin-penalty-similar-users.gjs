import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn, get, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import avatar from "discourse/helpers/avatar";
import formatDuration from "discourse/helpers/format-duration";
import htmlSafe from "discourse/helpers/html-safe";
import number from "discourse/helpers/number";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";

export default class AdminPenaltySimilarUsers extends Component {
  @tracked isLoading;
  @tracked similarUsers = [];
  selectedUserIds = [];

  constructor() {
    super(...arguments);

    this.loadSimilarUsers();
  }

  get penaltyField() {
    const penaltyType = this.args.penaltyType;
    if (penaltyType === "suspend") {
      return "can_be_suspended";
    } else if (penaltyType === "silence") {
      return "can_be_silenced";
    }
  }

  async loadSimilarUsers() {
    this.isLoading = true;
    try {
      const data = await ajax(
        `/admin/users/${this.args.user.id}/similar-users.json`
      );
      this.similarUsers = data.users;
    } finally {
      this.isLoading = false;
    }
  }

  @action
  selectUserId(userId, event) {
    if (event.target.checked) {
      this.selectedUserIds.push(userId);
    } else {
      this.selectedUserIds = this.selectedUserIds.filter((id) => id !== userId);
    }

    this.args.onUsersChanged(this.selectedUserIds);
  }

  <template>
    <div class="penalty-similar-users">
      <p class="alert alert-warning">
        {{htmlSafe
          (i18n
            "admin.user.other_matches"
            (hash count=@user.similar_users_count username=@user.username)
          )
        }}
      </p>

      <ConditionalLoadingSpinner @condition={{this.isLoading}}>
        <table class="table">
          <thead>
            <tr>
              <th></th>
              <th>{{i18n "username"}}</th>
              <th>{{i18n "last_seen"}}</th>
              <th>{{i18n "admin.user.topics_entered"}}</th>
              <th>{{i18n "admin.user.posts_read_count"}}</th>
              <th>{{i18n "admin.user.time_read"}}</th>
              <th>{{i18n "created"}}</th>
            </tr>
          </thead>

          <tbody>
            {{#each this.similarUsers as |user|}}
              <tr>
                <td>
                  <Input
                    @type="checkbox"
                    disabled={{not (get user this.penaltyField)}}
                    {{on "click" (fn this.selectUserId user.id)}}
                  />
                </td>
                <td>{{avatar user imageSize="small"}} {{user.username}}</td>
                <td>{{formatDuration user.last_seen_age}}</td>
                <td>{{number user.topics_entered}}</td>
                <td>{{number user.posts_read_count}}</td>
                <td>{{formatDuration user.time_read}}</td>
                <td>{{formatDuration user.created_at_age}}</td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
