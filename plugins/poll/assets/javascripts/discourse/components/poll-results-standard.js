import Component from "@glimmer/component";
import evenRound from "discourse/plugins/poll/lib/even-round";

export default class PollResultsStandardComponent extends Component {
  pollName = this.args.attrs.poll.name;
  postId = this.args.attrs.post.id;
  pollType = this.args.attrs.poll.type;

  get voters() {
    return this.args.attrs.poll.preloaded_voters || [];
  }

  get orderedOptions() {
    const voters = this.args.attrs.poll.voters;

    let ordered = [...this.args.attrs.poll.options].sort((a, b) => {
      if (a.votes < b.votes) {
        return 1;
      } else if (a.votes === b.votes) {
        if (a.html < b.html) {
          return -1;
        } else {
          return 1;
        }
      } else {
        return -1;
      }
    });

    const percentages =
      voters === 0
        ? Array(ordered.length).fill(0)
        : ordered.map((o) => (100 * o.votes) / voters);

    const rounded = this.args.attrs.isMultiple
      ? percentages.map(Math.floor)
      : evenRound(percentages);

    ordered.forEach((option, idx) => {
      const per = rounded[idx].toString();
      const chosen = (this.args.attrs.vote || []).includes(option.id);
      option.percentage = per;
      option.chosen = chosen;
    });

    return ordered;
  }

  get isPublic() {
    return this.args.attrs.poll.public;
  }
}
