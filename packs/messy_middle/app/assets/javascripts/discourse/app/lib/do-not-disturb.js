export default class DoNotDisturb {
  static forever = "3000-01-01T00:00:00.000Z";

  static isEternal(until) {
    return moment.utc(until).isSame(DoNotDisturb.forever, "day");
  }
}
