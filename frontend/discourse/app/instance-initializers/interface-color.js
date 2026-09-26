import { lookup } from "discourse/lib/service";
import InterfaceColorService from "discourse/services/interface-color";
export default {
  after: "inject-objects",

  initialize(owner) {
    const interfaceColor = lookup(owner, InterfaceColorService);
    interfaceColor.ensureCorrectMode();
  },
};
