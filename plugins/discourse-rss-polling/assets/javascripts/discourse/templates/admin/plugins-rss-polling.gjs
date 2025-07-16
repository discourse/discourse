import { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import TagChooser from "select-kit/components/tag-chooser";

export default RouteTemplate(
  <template>
    <div class="rss-polling-feed-settings">
      <table>
        <thead>
          <tr>
            <th colspan="2">{{i18n "admin.rss_polling.feed"}}</th>
            <th colspan="3">{{i18n "admin.rss_polling.discourse"}}</th>
            <th rowspan="2" colspan="2">
              <DButton
                @action={{@controller.create}}
                @icon="plus"
                @disabled={{@controller.saving}}
                class="btn-primary wide-button add-rss-polling-feed"
              />
            </th>
          </tr>
          <tr>
            <th>{{i18n "admin.rss_polling.feed_url"}}</th>
            <th>{{i18n "admin.rss_polling.feed_category_filter"}}</th>
            <th>{{i18n "admin.rss_polling.author"}}</th>
            <th>{{i18n "admin.rss_polling.discourse_category"}}</th>
            <th>{{i18n "admin.rss_polling.discourse_tags"}}</th>
          </tr>
        </thead>

        <tbody>
          {{#each @controller.model as |setting|}}
            <tr>
              <td>
                <Input
                  @value={{setting.feed_url}}
                  placeholder="https://blog.example.com/feed"
                  disabled={{setting.disabled}}
                  class="rss-polling-feed-url"
                />
              </td>
              <td>
                <Input
                  @value={{setting.feed_category_filter}}
                  placeholder="updates"
                  disabled={{setting.disabled}}
                  class="rss-polling-feed-updates"
                />
              </td>
              <td>
                <EmailGroupUserChooser
                  @value={{setting.author_username}}
                  @onChange={{fn @controller.updateAuthorUsername setting}}
                  @options={{hash disabled=setting.disabled maximum=1}}
                  class="rss-polling-feed-user"
                />
              </td>
              <td>
                <CategoryChooser
                  @value={{setting.discourse_category_id}}
                  @onChange={{fn (mut setting.discourse_category_id)}}
                  @options={{hash disabled=setting.disabled}}
                  class="small rss-polling-feed-category"
                />
              </td>
              <td>
                <TagChooser
                  @tags={{setting.discourse_tags}}
                  @allowCreate={{false}}
                  @everyTag={{true}}
                  @unlimitedTagCount={{true}}
                  @onChange={{fn (mut setting.discourse_tags)}}
                  @options={{hash disabled=setting.disabled}}
                  class="small rss-polling-feed-tag"
                />
              </td>
              <td>
                {{#if setting.editing}}
                  <DButton
                    @icon="floppy-disk"
                    @action={{fn @controller.updateFeedSetting setting}}
                    @disabled={{@controller.unsavable}}
                    class="btn-primary save-rss-polling-feed"
                  />
                  <DButton
                    @icon="xmark"
                    @action={{fn @controller.cancelEdit setting}}
                    @disabled={{@controller.saving}}
                  />
                {{else}}
                  <DButton
                    @icon="pencil"
                    @action={{fn @controller.editFeedSetting setting}}
                    @disabled={{@controller.saving}}
                  />
                  <DButton
                    @icon="trash-can"
                    @action={{fn @controller.destroyFeedSetting setting}}
                    @disabled={{@controller.saving}}
                  />
                {{/if}}
              </td>
            </tr>
          {{/each}}
        </tbody>

        <tfoot>
          <tr>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
            <td></td>
          </tr>
        </tfoot>
      </table>

      <p>
        <a
          href="https://meta.discourse.org/t/configure-the-discourse-rss-polling-plugin/156387"
        >
          {{i18n "admin.rss_polling.documentation"}}
        </a>
      </p>
    </div>
  </template>
);
