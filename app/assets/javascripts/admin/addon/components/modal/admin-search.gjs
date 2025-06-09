import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import AdminSearch from "admin/components/admin-search";

export default class AdminSearchModal extends Component {
  @service currentUser;
  @service router;

  constructor() {
    super(...arguments);
    this.router.on("routeWillChange", this.args.closeModal);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeWillChange", this.args.closeModal);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="admin-search-modal --quick-palette"
      @title="admin.search.modal_title"
      @inline={{@inline}}
      @hideHeader={{true}}
    >
      <AdminSearch />
    </DModal>
  </template>
}
