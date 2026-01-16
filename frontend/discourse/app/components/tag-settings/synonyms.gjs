import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import InterpolatedTranslation from "discourse/components/interpolated-translation";
import discourseTag from "discourse/helpers/discourse-tag";
import TagChooser from "discourse/select-kit/components/tag-chooser";
import { i18n } from "discourse-i18n";

export default class TagSettingsSynonyms extends Component {
  get hasSynonyms() {
    return this.args.synonyms && this.args.synonyms.length > 0;
  }

  get blockedTags() {
    const blocked = [];
    if (this.args.tag) {
      blocked.push(this.args.tag.name);
    }
    if (this.args.synonyms) {
      blocked.push(...this.args.synonyms.map((s) => s.name));
    }
    return blocked;
  }

  @action
  removeSynonym(synonym) {
    const currentSynonyms = this.args.synonyms || [];
    const updatedSynonyms = currentSynonyms.filter((s) => s.id !== synonym.id);
    this.args.form?.set("synonyms", updatedSynonyms);

    const removedIds = this.args.removedSynonymIds || [];
    this.args.form?.set("removed_synonym_ids", [...removedIds, synonym.id]);
  }

  @action
  setNewSynonyms(tags) {
    const normalized = tags?.map((t) => ({ id: t.id, name: t.name }));
    this.args.form?.set("new_synonyms", normalized);
  }

  <template>
    <div class="tag-settings-synonyms">
      {{#if this.hasSynonyms}}
        <div class="tag-settings-synonyms__list">
          {{#each @synonyms as |synonym|}}
            <div class="tag-settings-synonyms__item">
              <span class="synonym-tag">
                {{discourseTag synonym.name}}
              </span>
              <DButton
                @action={{fn this.removeSynonym synonym}}
                @icon="xmark"
                @title="tagging.remove_synonym"
                class="btn-flat btn-small"
              />
            </div>
          {{/each}}
        </div>
      {{else}}
        <p class="tag-settings-synonyms__empty">
          {{i18n "tagging.settings.no_synonyms"}}
        </p>
      {{/if}}

      <TagChooser
        @tags={{@newSynonyms}}
        @onChange={{this.setNewSynonyms}}
        @everyTag={{true}}
        @blockedTags={{this.blockedTags}}
        @options={{hash
          filterPlaceholder="tagging.settings.add_synonym_placeholder"
        }}
        class="tag-settings-synonyms__chooser"
      />

      <p class="tag-settings-synonyms__hint">
        <InterpolatedTranslation
          @key="tagging.settings.synonyms_hint"
          as |Placeholder|
        >
          <Placeholder @name="baseTagName">
            <b>{{@tag.name}}</b>
          </Placeholder>
        </InterpolatedTranslation>
      </p>
    </div>
  </template>
}
