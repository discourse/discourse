export default {
  after: "message-bus",

  initialize() {
    moment.tz.link(["Asia/Kolkata|IST", "Asia/Seoul|KST", "Asia/Tokyo|JST"]);
    delete moment.tz._links["us_pacific-new"];
  },
};
