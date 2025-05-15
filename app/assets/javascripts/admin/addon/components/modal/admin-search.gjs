import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import AdminSearch from "admin/components/admin-search";

export default class AdminSearchModal extends Component {
  @service currentUser;

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
