import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { AUTO_GROUPS } from "discourse/lib/constants";
import Category from "discourse/models/category";
import CategorySelector from "discourse/select-kit/components/category-selector";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import { i18n } from "discourse-i18n";
import PeriodInput from "discourse/plugins/discourse-gamification/discourse/components/period-input";

const SCORABLE_KEYS = [
  "like_given",
  "like_received",
  "post_created",
  "topic_created",
  "solution",
  "day_visited",
  "flag_created",
  "post_read",
  "time_read",
  "user_invited",
  "reaction_given",
  "reaction_received",
  "chat_message_created",
  "chat_reaction_given",
  "chat_reaction_received",
];

export default class AdminEditLeaderboard extends Component {
  @service site;
  @service toasts;
  @service router;

  @tracked selectedScorableCategories = [];

  constructor() {
    super(...arguments);

    this.pendingScorableCategoriesRequest = Promise.resolve();
    this.syncSelectedScorableCategories(
      this.args.leaderboard.scorableCategoryIds
    );
  }

  get siteGroups() {
    return this.site.groups.filter(
      (group) => group.id !== AUTO_GROUPS.everyone.id
    );
  }

  async updateSelectedScorableCategories(ids, previousRequest) {
    const categories = ids?.length ? await Category.asyncFindByIds(ids) : [];

    await previousRequest;

    this.selectedScorableCategories = categories;
  }

  get formData() {
    const overrides = this.args.leaderboard.scoreOverrides || {};

    const data = {
      name: this.args.leaderboard.name,
      from_date: this.args.leaderboard.fromDate,
      to_date: this.args.leaderboard.toDate,
      included_groups_ids: this.args.leaderboard.includedGroupsIds,
      excluded_groups_ids: this.args.leaderboard.excludedGroupsIds,
      visible_to_groups_ids: this.args.leaderboard.visibleToGroupsIds,
      default_period: this.args.leaderboard.defaultPeriod,
      period_filter_disabled: this.args.leaderboard.periodFilterDisabled,
      scorable_category_ids: this.args.leaderboard.scorableCategoryIds,
    };

    for (const key of SCORABLE_KEYS) {
      data[`score_override_${key}`] =
        overrides[key] !== undefined ? String(overrides[key]) : "";
    }

    return data;
  }

  @action
  syncSelectedScorableCategories(ids) {
    const previousRequest = this.pendingScorableCategoriesRequest;
    this.pendingScorableCategoriesRequest =
      this.updateSelectedScorableCategories(ids, previousRequest);
  }

  @action
  onCategoryChange(set, categories) {
    this.selectedScorableCategories = categories || [];
    set((categories || []).map((c) => c.id));
  }

  @action
  async save(data) {
    const scoreOverrides = {};
    let hasOverrides = false;

    for (const key of SCORABLE_KEYS) {
      const val = data[`score_override_${key}`];
      if (val !== "" && val !== null && val !== undefined) {
        scoreOverrides[key] = parseInt(val, 10);
        hasOverrides = true;
      }
    }

    const payload = {
      name: data.name,
      from_date: data.from_date,
      to_date: data.to_date,
      included_groups_ids: data.included_groups_ids,
      excluded_groups_ids: data.excluded_groups_ids,
      visible_to_groups_ids: data.visible_to_groups_ids,
      default_period: data.default_period,
      period_filter_disabled: data.period_filter_disabled,
      scorable_category_ids: data.scorable_category_ids,
    };

    if (hasOverrides) {
      payload.score_overrides = scoreOverrides;
    }

    try {
      await ajax(
        `/admin/plugins/gamification/leaderboard/${this.args.leaderboard.id}`,
        {
          data: payload,
          type: "PUT",
        }
      );
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("gamification.leaderboard.save_success"),
        },
      });
      await this.router.transitionTo(
        "adminPlugins.show.discourse-gamification-leaderboards.index"
      );

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
        @type="input"
        as |field|
      >
        <field.Control />
      </form.Field>

      <form.Section
        @title={{i18n "gamification.leaderboard.section.time_period"}}
        @subtitle={{i18n
          "gamification.leaderboard.section.time_period_description"
        }}
      >
        <form.Row as |row|>
          <row.Col @size={{6}}>
            <form.Field
              @name="from_date"
              @title={{i18n "gamification.leaderboard.date.from"}}
              @type="input-date"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>

          <row.Col @size={{6}}>
            <form.Field
              @name="to_date"
              @title={{i18n "gamification.leaderboard.date.to"}}
              @type="input-date"
              as |field|
            >
              <field.Control />
            </form.Field>
          </row.Col>
        </form.Row>

        <form.Field
          @name="period_filter_disabled"
          @title={{i18n "gamification.leaderboard.period_filter_disabled"}}
          @type="toggle"
          as |field|
        >
          <field.Control />
        </form.Field>

        <form.Field
          @name="default_period"
          @title={{i18n "gamification.leaderboard.default_period"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <PeriodInput @value={{field.value}} @onChange={{field.set}} />
          </field.Control>
        </form.Field>
      </form.Section>

      <form.Section
        @title={{i18n "gamification.leaderboard.section.groups"}}
        @subtitle={{i18n "gamification.leaderboard.section.groups_description"}}
      >
        <form.Field
          @name="included_groups_ids"
          @title={{i18n "gamification.leaderboard.included_groups"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <GroupChooser
              @id="leaderboard-edit__included-groups"
              @content={{this.siteGroups}}
              @value={{field.value}}
              @labelProperty="name"
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>

        <form.Field
          @name="excluded_groups_ids"
          @title={{i18n "gamification.leaderboard.excluded_groups"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <GroupChooser
              @id="leaderboard-edit__excluded-groups"
              @content={{this.siteGroups}}
              @value={{field.value}}
              @labelProperty="name"
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>

        <form.Field
          @name="visible_to_groups_ids"
          @title={{i18n "gamification.leaderboard.visible_to_groups"}}
          @type="custom"
          as |field|
        >
          <field.Control>
            <GroupChooser
              @id="leaderboard-edit__visible-groups"
              @content={{this.siteGroups}}
              @value={{field.value}}
              @labelProperty="name"
              @onChange={{field.set}}
            />
          </field.Control>
        </form.Field>
      </form.Section>

      <details class="leaderboard-scoring-details">
        <summary>{{i18n
            "gamification.leaderboard.scoring_configuration"
          }}</summary>

        <p class="leaderboard-scoring-details__description">{{i18n
            "gamification.leaderboard.scoring_configuration_description"
          }}</p>

        <form.Section
          @title={{i18n "gamification.leaderboard.scorable_categories"}}
        >
          <form.Field
            @name="scorable_category_ids"
            @title={{i18n "gamification.leaderboard.scorable_categories"}}
            @description={{i18n
              "gamification.leaderboard.scorable_categories_help"
            }}
            @type="custom"
            as |field|
          >
            <field.Control>
              <div
                {{didUpdate
                  (fn this.syncSelectedScorableCategories field.value)
                  field.value
                }}
              >
                <CategorySelector
                  @categories={{this.selectedScorableCategories}}
                  @onChange={{fn this.onCategoryChange field.set}}
                />
              </div>
            </field.Control>
          </form.Field>
        </form.Section>

        <form.Section
          @title={{i18n "gamification.leaderboard.score_overrides"}}
          @subtitle={{i18n "gamification.leaderboard.score_overrides_help"}}
        >
          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_like_given"
                @title={{i18n "gamification.leaderboard.weight.like_given"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_like_received"
                @title={{i18n "gamification.leaderboard.weight.like_received"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_post_created"
                @title={{i18n "gamification.leaderboard.weight.post_created"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_topic_created"
                @title={{i18n "gamification.leaderboard.weight.topic_created"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_solution"
                @title={{i18n "gamification.leaderboard.weight.solution"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_flag_created"
                @title={{i18n "gamification.leaderboard.weight.flag_created"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_day_visited"
                @title={{i18n "gamification.leaderboard.weight.day_visited"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_user_invited"
                @title={{i18n "gamification.leaderboard.weight.user_invited"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_post_read"
                @title={{i18n "gamification.leaderboard.weight.post_read"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_time_read"
                @title={{i18n "gamification.leaderboard.weight.time_read"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_reaction_given"
                @title={{i18n "gamification.leaderboard.weight.reaction_given"}}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_reaction_received"
                @title={{i18n
                  "gamification.leaderboard.weight.reaction_received"
                }}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Row as |row|>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_chat_message_created"
                @title={{i18n
                  "gamification.leaderboard.weight.chat_message_created"
                }}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
            <row.Col @size={{6}}>
              <form.Field
                @name="score_override_chat_reaction_given"
                @title={{i18n
                  "gamification.leaderboard.weight.chat_reaction_given"
                }}
                @type="input-number"
                as |field|
              >
                <field.Control min="0" step="1" />
              </form.Field>
            </row.Col>
          </form.Row>

          <form.Field
            @name="score_override_chat_reaction_received"
            @title={{i18n
              "gamification.leaderboard.weight.chat_reaction_received"
            }}
            @type="input-number"
            as |field|
          >
            <field.Control min="0" step="1" />
          </form.Field>
        </form.Section>
      </details>

      <form.Submit />
    </Form>
  </template>
}
