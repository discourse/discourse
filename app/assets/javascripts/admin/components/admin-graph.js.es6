import Component from "@ember/component";
import loadScript from "discourse/lib/load-script";

export default Component.extend({
  tagName: "canvas",
  type: "line",

  refreshChart() {
    const ctx = this.element.getContext("2d");
    const model = this.model;
    const rawData = this.get("model.data");

    var data = {
      labels: rawData.map(r => r.x),
      datasets: [
        {
          data: rawData.map(r => r.y),
          label: model.get("title"),
          backgroundColor: `rgba(200,220,240,${this.type === "bar" ? 1 : 0.3})`,
          borderColor: "#08C"
        }
      ]
    };

    const config = {
      type: this.type,
      data: data,
      options: {
        responsive: true,
        tooltips: {
          callbacks: {
            title: context =>
              moment(context[0].xLabel, "YYYY-MM-DD").format("LL")
          }
        },
        scales: {
          yAxes: [
            {
              display: true,
              ticks: {
                stepSize: 1
              }
            }
          ]
        }
      }
    };

    this._chart = new window.Chart(ctx, config);
  },

  didInsertElement() {
    loadScript("/javascripts/Chart.min.js").then(() =>
      this.refreshChart.apply(this)
    );
  }
});
