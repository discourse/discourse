import { tracked } from "@glimmer/tracking";

export default class DiscoursePostEventEventStats {
  static create(args = {}) {
    return new DiscoursePostEventEventStats(args);
  }

  @tracked going = 0;
  @tracked interested = 0;
  @tracked invited = 0;
  @tracked notGoing = 0;

  constructor(args = {}) {
    this.going = args.going;
    this.invited = args.invited;
    this.interested = args.interested;
    this.notGoing = args.not_going;
  }
}
