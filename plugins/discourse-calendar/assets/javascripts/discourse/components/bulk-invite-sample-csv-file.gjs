import Component from "@ember/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";

export default class BulkInviteSampleCsvFile extends Component {
  @action
  downloadSampleCsv() {
    const sampleData = [
      ["my_awesome_group", "going"],
      ["lucy", "interested"],
      ["mark", "not_going"],
      ["sam", "unknown"],
    ];

    let csv = "";
    sampleData.forEach((row) => {
      csv += row.join(",");
      csv += "\n";
    });

    const btn = document.createElement("a");
    btn.href = `data:text/csv;charset=utf-8,${encodeURI(csv)}`;
    btn.target = "_blank";
    btn.rel = "noopener noreferrer";
    btn.download = "bulk-invite-sample.csv";
    btn.click();
  }

  <template>
    <DButton
      @label="discourse_post_event.bulk_invite_modal.download_sample_csv"
      {{! template-lint-disable no-action }}
      @action={{action "downloadSampleCsv"}}
    />
  </template>
}
