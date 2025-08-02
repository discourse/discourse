import Component from "@glimmer/component";
import I18n from "discourse-i18n";

export default class TopicViews extends Component {
  adjustAggregatedData(stats) {
    const adjustedStats = [];

    stats.forEach((stat) => {
      const localDate = new Date(`${stat.viewed_at}T00:00:00Z`);
      const localDateStr = localDate.toLocaleDateString(
        I18n.currentBcp47Locale,
        {
          year: "numeric",
          month: "2-digit",
          day: "2-digit",
        }
      );

      const existingStat = adjustedStats.find(
        (s) => s.dateStr === localDateStr
      );

      if (existingStat) {
        existingStat.views += stat.views;
      } else {
        adjustedStats.push({
          dateStr: localDateStr,
          views: stat.views,
          localDate,
        });
      }
    });

    return adjustedStats.map((stat) => ({
      viewed_at: stat.localDate.toISOString().split("T")[0],
      views: stat.views,
    }));
  }

  formatDate(date) {
    return date.toLocaleDateString(I18n.currentBcp47Locale, {
      month: "2-digit",
      day: "2-digit",
    });
  }

  get updatedStats() {
    const adjustedStats = this.adjustAggregatedData(this.args.views.stats);

    let stats = adjustedStats.map((stat) => {
      const statDate = new Date(`${stat.viewed_at}T00:00:00`).getTime();
      const localStatDate = new Date(statDate);

      return {
        ...stat,
        statDate: localStatDate,
        label: this.formatDate(localStatDate),
      };
    });

    // today should always have at least 1 view
    // because it's being viewed right now
    const lastStat = stats[stats.length - 1];
    lastStat.views = Math.max(lastStat.views, 1);

    return stats;
  }

  <template>
    <div class="topic-views__wrapper">
      {{#each this.updatedStats as |stat|}}
        <div class="topic-views">
          <div class="topic-views__count">
            {{stat.views}}
          </div>
          <div class="topic-views__date">
            {{stat.label}}
          </div>
        </div>
      {{/each}}
    </div>
  </template>
}
