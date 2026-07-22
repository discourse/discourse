import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import DVirtualListTableSpike from "discourse/ui-kit/d-virtual-list-table-spike";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const ROW_COUNT = 2000;

export default class VirtualTableMolecule extends Component {
  estimateSize = () => 41;
  columns = ["12%", "28%", "42%", "18%"];

  @cached
  get rows() {
    return Array.from({ length: ROW_COUNT }, (_, index) => ({
      id: index + 1,
      name: `User ${index + 1}`,
      email: `user${index + 1}@example.com`,
      score: (index * 37) % 100,
    }));
  }

  <template>
    <StyleguideExample
      @title="Virtualized <table> — spacer layout (the one case per-row translate can't serve)"
    >
      <div class="styleguide-virtual-list">
        <p class="styleguide-virtual-list__note">
          A real
          <code>&lt;table&gt;</code>
          of
          {{ROW_COUNT}}
          rows. A
          <code>&lt;tr&gt;</code>
          cannot be
          <code>position: absolute</code>
          without collapsing table layout, so the window is offset with spacer
          <code>&lt;tr&gt;&lt;td colspan&gt;</code>
          rows in normal flow. A single table with a
          <code>position: sticky</code>
          <code>&lt;thead&gt;</code>
          and a virtualized
          <code>&lt;tbody&gt;</code>: the header stays put while the body
          scrolls — a table-shaped feature flow layout gives for free and
          absolute rows would break. Scroll and inspect: only a window of
          <code>&lt;tr&gt;</code>
          rows is in the DOM, bracketed by the two spacer rows.
        </p>

        <DVirtualListTableSpike
          @items={{this.rows}}
          @key="id"
          @estimateSize={{this.estimateSize}}
          @columnWidths={{this.columns}}
        >
          <:header>
            <th>ID</th>
            <th>Name</th>
            <th>Email</th>
            <th>Score</th>
          </:header>
          <:default as |user|>
            <td>{{user.id}}</td>
            <td>{{user.name}}</td>
            <td>{{user.email}}</td>
            <td>{{user.score}}</td>
          </:default>
        </DVirtualListTableSpike>
      </div>
    </StyleguideExample>
  </template>
}
