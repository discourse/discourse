// This file should only be async imported

import { faker } from "@faker-js/faker";

export default class Fabricator {
  static generate() {
    return faker.lorem.lines(4);
  }
}
