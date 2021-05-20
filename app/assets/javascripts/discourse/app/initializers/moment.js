export default {
  name: "moment",
  after: "message-bus",

  initialize() {
    delete moment.tz._links["us_pacific-new"];
  },
};
