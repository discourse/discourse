import Component from "@glimmer/component";

export default class NewListHeaderControlsWrapper extends Component {
  click(e) {
    const target = e.target;
    if (target.closest("button.topics-replies-toggle.--all")) {
      this.args.changeNewListSubset(null);
    } else if (target.closest("button.topics-replies-toggle.--topics")) {
      this.args.changeNewListSubset("topics");
    } else if (target.closest("button.topics-replies-toggle.--replies")) {
      this.args.changeNewListSubset("replies");
    }
  }
}
