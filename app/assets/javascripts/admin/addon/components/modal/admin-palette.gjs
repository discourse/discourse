import Component from "@glimmer/component";
import { service } from "@ember/service";
import DModal from "discourse/components/d-modal";
import AdminPaletteSearch from "admin/components/admin-palette-search";

export default class AdminPaletteModal extends Component {
  @service currentUser;

  <template>
    <DModal
      @closeModal={{@closeModal}}
      class="admin-palette-modal"
      @title="admin.palette.search"
      @inline={{@inline}}
      @hideHeader={{true}}
    >
      <AdminPaletteSearch />
    </DModal>
  </template>
}
