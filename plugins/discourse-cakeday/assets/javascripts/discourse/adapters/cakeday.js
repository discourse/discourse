import RESTAdapter from "discourse/adapters/rest";

export default class Cakeday extends RESTAdapter {
  basePath() {
    return "/cakeday/";
  }
}
