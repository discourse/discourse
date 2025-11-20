import Component from "@glimmer/component";
import { service } from "@ember/service";
import { optionalRequire } from "discourse/lib/utilities";

export default class ReviewableIpLookup extends Component {
  @service currentUser;

  get showIpLookup() {
    return (
      this.args.reviewable.type !== "ReviewableUser" &&
      this.currentUser.staff &&
      this.args.reviewable.target_created_by
    );
  }

  get IpLookupComponent() {
    return optionalRequire("discourse/admin/components/ip-lookup");
  }

  <template>
    {{#if this.showIpLookup}}
      <div class="reviewable-ip-lookup">
        <this.IpLookupComponent
          @ip="adminLookup"
          @userId={{@reviewable.target_created_by.id}}
        />
      </div>
    {{/if}}
  </template>
}
