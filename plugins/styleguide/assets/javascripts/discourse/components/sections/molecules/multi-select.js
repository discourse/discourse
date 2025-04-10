import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class MultiSelect extends Component {
  @action
  async loadDummyData(filter) {
    await new Promise((resolve) => setTimeout(resolve, 500));

    return [
      { id: 1, name: "foo" },
      { id: 2, name: "bar" },
      { id: 3, name: "baz" },
    ].filter((item) => {
      return item.name.toLowerCase().includes(filter.toLowerCase());
    });
  }
}
