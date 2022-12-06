export class AnonymousUser {
  #timezone = null;

  get timezone() {
    if (!this.#timezone) {
      this.#timezone = moment.tz.guess();
    }

    return this.#timezone;
  }
}
