import { computed } from "@ember/object";
import AdminDashboardTabController from "admin/controllers/admin-dashboard-tab";

export default class AdminDashboardSentiment extends AdminDashboardTabController {
  @computed("startDate", "endDate")
  get filters() {
    return { startDate: this.startDate, endDate: this.endDate };
  }

  get emotionFilters() {
    return {
      startDate: moment().subtract(2, "month").format("YYYY-MM-DD"),
      endDate: moment().format("YYYY-MM-DD"),
    };
  }

  get emotions() {
    const emotions = [
      "admiration",
      "amusement",
      "anger",
      "annoyance",
      "approval",
      "caring",
      "confusion",
      "curiosity",
      "desire",
      "disappointment",
      "disapproval",
      "disgust",
      "embarrassment",
      "excitement",
      "fear",
      "gratitude",
      "grief",
      "joy",
      "love",
      "nervousness",
      "neutral",
      "optimism",
      "pride",
      "realization",
      "relief",
      "remorse",
      "sadness",
      "surprise",
    ];
    return emotions;
  }
}
