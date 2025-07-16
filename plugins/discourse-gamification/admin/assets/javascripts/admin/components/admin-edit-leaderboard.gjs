import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import { i18n } from "discourse-i18n";
import GroupChooser from "select-kit/components/group-chooser";
import PeriodInput from "discourse/plugins/discourse-gamification/discourse/components/period-input";

export default class AdminEditLeaderboard extends Component {
  @service currentUser;
  @service site;
  @service toasts;
  @service router;

  get siteGroups() {
    return this.site.groups.rejectBy("id", AUTO_GROUPS.everyone.id);
  }

  get formData() {
    return {
      name: this.args.leaderboard.name,
      from_date: this.args.leaderboard.fromDate,
      to_date: this.args.leaderboard.toDate,
      included_groups_ids: this.args.leaderboard.includedGroupsIds,
      excluded_groups_ids: this.args.leaderboard.excludedGroupsIds,
      visible_to_groups_ids: this.args.leaderboard.visibleToGroupsIds,
      default_period: this.args.leaderboard.defaultPeriod,
      period_filter_disabled: this.args.leaderboard.periodFilterDisabled,
    };
  }

  @action
  async save(data) {
    try {
      await ajax(
        `/admin/plugins/gamification/leaderboard/${this.args.leaderboard.id}`,
        {
          data,
          type: "PUT",
        }
      );
      this.toasts.success({
        duration: 3000,
        data: {
          message: i18n("gamification.leaderboard.save_success"),
        },
      });
      await this.router.transitionTo(
        "adminPlugins.show.discourse-gamification-leaderboards.index"
      );

      // To refresh the list of leaderboards in the index.
      this.router.refresh();
    } catch (err) {
      popupAjaxError(err);
    }
  }

  <template>
    <BackButton
      @route="adminPlugins.show.discourse-gamification-leaderboards"
      @label="gamification.back"
    />
    <Form
      @data={{this.formData}}
      @onSubmit={{this.save}}
      class="edit-create-leaderboard-form"
      as |form|
    >
      <form.Field
        @name="name"
        @title={{i18n "gamification.leaderboard.name"}}
        @validation="required"
        as |field|
      >
        <field.Input />
      </form.Field>

      <form.Row as |row|>
        <row.Col @size={{6}}>
          <form.Field
            @name="from_date"
            @title={{i18n "gamification.leaderboard.date.from"}}
            as |field|
          >
            <field.Input @type="date" />
          </form.Field>
        </row.Col>

        <row.Col @size={{6}}>
          <form.Field
            @name="to_date"
            @title={{i18n "gamification.leaderboard.date.to"}}
            as |field|
          >
            <field.Input @type="date" />
          </form.Field>
        </row.Col>
      </form.Row>

      <form.Field
        @name="included_groups_ids"
        @title={{i18n "gamification.leaderboard.included_groups"}}
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @id="leaderboard-edit__included-groups"
            @content={{this.siteGroups}}
            @value={{field.value}}
            @labelProperty="name"
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="excluded_groups_ids"
        @title={{i18n "gamification.leaderboard.excluded_groups"}}
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @id="leaderboard-edit__excluded-groups"
            @content={{this.siteGroups}}
            @value={{field.value}}
            @labelProperty="name"
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="visible_to_groups_ids"
        @title={{i18n "gamification.leaderboard.visible_to_groups"}}
        as |field|
      >
        <field.Custom>
          <GroupChooser
            @id="leaderboard-edit__visible-groups"
            @content={{this.siteGroups}}
            @value={{field.value}}
            @labelProperty="name"
            @onChange={{field.set}}
          />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="default_period"
        @title={{i18n "gamification.leaderboard.default_period"}}
        as |field|
      >
        <field.Custom>
          <PeriodInput @value={{field.value}} @onChange={{field.set}} />
        </field.Custom>
      </form.Field>

      <form.Field
        @name="period_filter_disabled"
        @title={{i18n "gamification.leaderboard.period_filter_disabled"}}
        @showTitle={{false}}
        as |field|
      >
        <field.Checkbox @value={{field.value}} />
      </form.Field>
      <form.Submit />
    </Form>
  </template>
}
