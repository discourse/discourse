import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import checkIcon from "admin/helpers/check-icon";

export default RouteTemplate(
  <template>
    <div class="admin-controls">
      <nav>
        <ul class="nav nav-pills">
          <li><LinkTo @route="adminUser" @model={{@controller.model}}>{{icon
                "caret-left"
              }}
              &nbsp;{{@controller.model.username}}</LinkTo></li>
          <li><LinkTo @route="adminUsersList.show" @model="member">{{i18n
                "admin.user.trust_level_2_users"
              }}</LinkTo></li>
        </ul>
      </nav>
    </div>

    <div class="admin-container tl3-requirements">
      <h2>{{@controller.model.username}}
        -
        {{i18n "admin.user.tl3_requirements.title"}}</h2>
      <br />
      <p>{{i18n
          "admin.user.tl3_requirements.table_title"
          count=@controller.model.tl3Requirements.time_period
        }}</p>

      <table class="table" style="width: auto;">
        <thead>
          <tr>
            <th></th>
            <th></th>
            <th>{{i18n "admin.user.tl3_requirements.value_heading"}}</th>
            <th>{{i18n "admin.user.tl3_requirements.requirement_heading"}}</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.topics_replied_to"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.topics_replied_to
              }}</td>
            <td>{{#if
                @controller.model.tl3Requirements.capped_topics_replied_to
              }}&ge;
              {{/if}}{{@controller.model.tl3Requirements.num_topics_replied_to}}</td>
            <td>{{@controller.model.tl3Requirements.min_topics_replied_to}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.topics_viewed"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.topics_viewed
              }}</td>
            <td>{{@controller.model.tl3Requirements.topics_viewed}}</td>
            <td>{{@controller.model.tl3Requirements.min_topics_viewed}}</td>
          </tr>
          <tr>
            <th>{{i18n
                "admin.user.tl3_requirements.topics_viewed_all_time"
              }}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.topics_viewed_all_time
              }}</td>
            <td
            >{{@controller.model.tl3Requirements.topics_viewed_all_time}}</td>
            <td
            >{{@controller.model.tl3Requirements.min_topics_viewed_all_time}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.posts_read"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.posts_read
              }}</td>
            <td>{{@controller.model.tl3Requirements.posts_read}}</td>
            <td>{{@controller.model.tl3Requirements.min_posts_read}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.posts_read_days"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.days_visited
              }}</td>
            <td>
              {{@controller.model.tl3Requirements.days_visited_percent}}% ({{@controller.model.tl3Requirements.days_visited}}
              /
              {{@controller.model.tl3Requirements.time_period}}
              {{i18n "admin.user.tl3_requirements.days"}})
            </td>
            <td
            >{{@controller.model.tl3Requirements.min_days_visited_percent}}%</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.posts_read_all_time"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.posts_read_all_time
              }}</td>
            <td>{{@controller.model.tl3Requirements.posts_read_all_time}}</td>
            <td
            >{{@controller.model.tl3Requirements.min_posts_read_all_time}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.flagged_posts"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.flagged_posts
              }}</td>
            <td>{{@controller.model.tl3Requirements.num_flagged_posts}}</td>
            <td>{{i18n
                "max_of_count"
                count=@controller.model.tl3Requirements.max_flagged_posts
              }}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.flagged_by_users"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.flagged_by_users
              }}</td>
            <td>{{@controller.model.tl3Requirements.num_flagged_by_users}}</td>
            <td>{{i18n
                "max_of_count"
                count=@controller.model.tl3Requirements.max_flagged_by_users
              }}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.likes_given"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.likes_given
              }}</td>
            <td>{{@controller.model.tl3Requirements.num_likes_given}}</td>
            <td>{{@controller.model.tl3Requirements.min_likes_given}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.likes_received"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.likes_received
              }}</td>
            <td>{{@controller.model.tl3Requirements.num_likes_received}}</td>
            <td>{{@controller.model.tl3Requirements.min_likes_received}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.likes_received_days"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.likes_received_days
              }}</td>
            <td
            >{{@controller.model.tl3Requirements.num_likes_received_days}}</td>
            <td
            >{{@controller.model.tl3Requirements.min_likes_received_days}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.likes_received_users"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.likes_received_users
              }}</td>
            <td
            >{{@controller.model.tl3Requirements.num_likes_received_users}}</td>
            <td
            >{{@controller.model.tl3Requirements.min_likes_received_users}}</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.silenced"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.silenced
              }}</td>
            <td
            >{{@controller.model.tl3Requirements.penalty_counts.silenced}}</td>
            <td>0</td>
          </tr>
          <tr>
            <th>{{i18n "admin.user.tl3_requirements.suspended"}}</th>
            <td>{{checkIcon
                @controller.model.tl3Requirements.met.suspended
              }}</td>
            <td
            >{{@controller.model.tl3Requirements.penalty_counts.suspended}}</td>
            <td>0</td>
          </tr>
        </tbody>
      </table>

      <br />
      <p>
        {{#if @controller.model.istl3}}
          {{#if @controller.model.tl3Requirements.requirements_lost}}
            {{! tl implicitly not locked }}
            {{#if @controller.model.tl3Requirements.on_grace_period}}
              {{icon "xmark"}}
              {{i18n "admin.user.tl3_requirements.on_grace_period"}}
            {{else}}
              {{! not on grace period }}
              {{icon "xmark"}}
              {{i18n "admin.user.tl3_requirements.does_not_qualify"}}
              {{i18n "admin.user.tl3_requirements.will_be_demoted"}}
            {{/if}}
          {{else}}
            {{! requirements not lost - remains tl3 }}
            {{#if @controller.model.tl3Requirements.trust_level_locked}}
              {{icon "lock"}}
              {{i18n "admin.user.tl3_requirements.locked_will_not_be_demoted"}}
            {{else}}
              {{! tl not locked }}
              {{icon "check"}}
              {{i18n "admin.user.tl3_requirements.qualifies"}}
              {{#if @controller.model.tl3Requirements.on_grace_period}}
                {{i18n "admin.user.tl3_requirements.on_grace_period"}}
              {{/if}}
            {{/if}}
          {{/if}}
        {{else}}
          {{! is not tl3 }}
          {{#if @controller.model.tl3Requirements.requirements_met}}
            {{! met & not tl3 - will be promoted}}
            {{icon "check"}}
            {{i18n "admin.user.tl3_requirements.qualifies"}}
            {{i18n "admin.user.tl3_requirements.will_be_promoted"}}
          {{else}}
            {{! requirements not met - remains regular }}
            {{#if @controller.model.tl3Requirements.trust_level_locked}}
              {{icon "lock"}}
              {{i18n "admin.user.tl3_requirements.locked_will_not_be_promoted"}}
            {{else}}
              {{icon "xmark"}}
              {{i18n "admin.user.tl3_requirements.does_not_qualify"}}
            {{/if}}
          {{/if}}
        {{/if}}
      </p>
    </div>
  </template>
);
