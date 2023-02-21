import Component from "@ember/component";
export default class AdminWrapper extends Component {
  didInsertElement() {
    super.didInsertElement(...arguments);
    document.querySelector("html").classList.add("admin-area");
    document.querySelector("body").classList.add("admin-interface");
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    document.querySelector("html").classList.remove("admin-area");
    document.querySelector("body").classList.remove("admin-interface");
  }
}
