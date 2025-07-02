import { addSidebarPanel } from "discourse/lib/sidebar/custom-sections";
import AdminSidebarPanel from "admin/lib/sidebar/admin-sidebar";

export default {
  initialize() {
    addSidebarPanel(() => AdminSidebarPanel);
  },
};
