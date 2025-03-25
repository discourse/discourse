import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";

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
}

<div class="penalty-similar-users">
  <p class="alert alert-warning">
    {{html-safe
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
            <td>{{format-duration user.last_seen_age}}</td>
            <td>{{number user.topics_entered}}</td>
            <td>{{number user.posts_read_count}}</td>
            <td>{{format-duration user.time_read}}</td>
            <td>{{format-duration user.created_at_age}}</td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </ConditionalLoadingSpinner>
</div>