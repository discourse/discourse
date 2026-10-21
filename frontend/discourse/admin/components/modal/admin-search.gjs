import Component from "@glimmer/component";
import { service } from "@ember/service";
import AdminSearch from "discourse/admin/components/admin-search";
import DModal from "discourse/ui-kit/d-modal";

export default class AdminSearchModal extends Component {
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
      class="admin-search-modal --quick-palette"
      @closeModal={{@closeModal}}
      @hideHeader={{true}}
      @inline={{@inline}}
      @title="admin.search.modal_title"
    >
      <AdminSearch />
    </DModal>
  </template>
}
