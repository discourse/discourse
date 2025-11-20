import Component from "@glimmer/component";
import { service } from "@ember/service";
import { optionalRequire } from "discourse/lib/utilities";

export default class ReviewableIpLookup extends Component {
  @service currentUser;

  get showIpLookup() {
    return this.currentUser.staff && this.target;
  }

  get IpLookupComponent() {
    return optionalRequire("discourse/admin/components/ip-lookup");
  }

  get target() {
    return this.args.reviewable.type === "ReviewableUser"
      ? this.args.reviewable.target_user?.id
      : this.args.reviewable.target_created_by?.id;
  }

  <template>
    {{#if this.showIpLookup}}
      <div class="reviewable-ip-lookup">
        <this.IpLookupComponent @ip="adminLookup" @userId={{this.target}} />
      </div>
    {{/if}}
  </template>
}
