import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "truth-helpers";
import DModal from "discourse/components/d-modal";
import Category from "discourse/models/category";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import MiniTagChooser from "select-kit/components/mini-tag-chooser";
import MultiCategoryChooser from "select-kit/components/multi-category-chooser";

export default class EditDiscoveryFiltersModal extends Component {
  @service modal;
  @service store;

  @tracked status;
  @tracked inBookmarked = false;
  @tracked inPinned = false;
  @tracked createdBy;
  @tracked tags = [];
  @tracked categories = [];
  @tracked tagsIntersection = "any";

  constructor() {
    super(...arguments);
    this.parseQueryString(this.args.model.queryString);
  }

  async parseQueryString(queryString) {
    if (!queryString) {
      return;
    }

    const params = queryString.split(" ");
    for (const param of params) {
      const [key, value] = param.split(":");
      if (key === "status") {
        this.status = value;
      } else if (key === "in") {
        if (value.includes("bookmarked")) {
          this.inBookmarked = true;
        }
        if (value.includes("pinned")) {
          this.inPinned = true;
        }
      } else if (key === "created-by") {
        this.createdBy = value;
      } else if (key === "tags") {
        const tags = value.split(",");
        this.tags = await this.store.findAll("tag", { tags });
      } else if (key === "category") {
        this.categories = value
          .split(",")
          .map((slug) => {
            const category = Category.findBySlug(slug);
            return category ? category.id : null;
          })
          .filter(Boolean);
      }
    }
  }

  @action
  updateFilters() {
    let newQueryString = "";
    if (this.status) {
      newQueryString += `status:${this.status} `;
    }

    const inValues = [];
    if (this.inBookmarked) {
      inValues.push("bookmarked");
    }
    if (this.inPinned) {
      inValues.push("pinned");
    }
    if (inValues.length > 0) {
      newQueryString += `in:${inValues.join(",")} `;
    }

    if (this.createdBy) {
      newQueryString += `created-by:${this.createdBy} `;
    }

    if (this.tags.length > 0) {
      const tagOperator = this.tagsIntersection === "all" ? "+" : ",";
      const tagNames = this.tags.map((t) => t.id);
      newQueryString += `tags:${tagNames.join(tagOperator)} `;
    }

    if (this.categories.length > 0) {
      const categorySlugs = this.categories
        .map((id) => {
          const category = Category.findById(id);
          return category ? category.slug : null;
        })
        .filter(Boolean);
      newQueryString += `category:${categorySlugs.join(",")} `;
    }

    const finalQuery = newQueryString.trim();
    this.args.model.updateQueryString(finalQuery);
    this.args.model.updateTopicsListQueryParams(finalQuery);
    this.modal.close();
  }

  @action
  updateStatus(event) {
    this.status = event.target.value;
  }

  @action
  updateInBookmarked(event) {
    this.inBookmarked = event.target.checked;
  }

  @action
  updateInPinned(event) {
    this.inPinned = event.target.checked;
  }

  @action
  updateCreatedBy(users) {
    this.createdBy = users.join(",");
  }

  @action
  updateTags(tags) {
    this.tags = tags;
  }

  @action
  updateCategories(categories) {
    this.categories = categories;
  }

  @action
  updateTagsIntersection(event) {
    this.tagsIntersection = event.target.value;
  }

  <template>
    <DModal @title="Edit Filters" @closeModal={{@closeModal}}>
      <:body>
        <form>
          <div class="form-group">
            <label for="status">Status</label>
            <select id="status" {{on "change" this.updateStatus}}>
              <option value="" selected={{eq this.status ""}}></option>
              <option
                value="open"
                selected={{eq this.status "open"}}
              >Open</option>
              <option
                value="closed"
                selected={{eq this.status "closed"}}
              >Closed</option>
              <option
                value="archived"
                selected={{eq this.status "archived"}}
              >Archived</option>
              <option
                value="listed"
                selected={{eq this.status "listed"}}
              >Listed</option>
              <option
                value="unlisted"
                selected={{eq this.status "unlisted"}}
              >Unlisted</option>
              <option
                value="deleted"
                selected={{eq this.status "deleted"}}
              >Deleted</option>
              <option
                value="public"
                selected={{eq this.status "public"}}
              >Public</option>
            </select>
          </div>
          <div class="form-group">
            <label>In</label>
            <label class="checkbox-label">
              <input
                type="checkbox"
                id="in-bookmarked"
                checked={{this.inBookmarked}}
                {{on "change" this.updateInBookmarked}}
              />
              Bookmarked
            </label>
            <label class="checkbox-label">
              <input
                type="checkbox"
                id="in-pinned"
                checked={{this.inPinned}}
                {{on "change" this.updateInPinned}}
              />
              Pinned
            </label>
          </div>
          <div class="form-group">
            <label for="created-by">Created By</label>
            <EmailGroupUserChooser
              @id="created-by"
              @value={{this.createdBy}}
              @onChange={{this.updateCreatedBy}}
            />
          </div>
          <div class="form-group">
            <label for="tags">Tags</label>
            <MiniTagChooser
              @id="tags"
              @value={{this.tags}}
              @onChange={{this.updateTags}}
            />
            <div class="tag-intersection">
              <label><input
                  type="radio"
                  name="tags-intersection"
                  value="any"
                  checked={{eq this.tagsIntersection "any"}}
                  {{on "change" this.updateTagsIntersection}}
                />
                Any</label>
              <label><input
                  type="radio"
                  name="tags-intersection"
                  value="all"
                  checked={{eq this.tagsIntersection "all"}}
                  {{on "change" this.updateTagsIntersection}}
                />
                All</label>
            </div>
          </div>
          <div class="form-group">
            <label for="category">Category</label>
            <MultiCategoryChooser
              @id="category"
              @value={{this.categories}}
              @onChange={{this.updateCategories}}
            />
          </div>
        </form>
      </:body>
      <:footer>
        <button class="btn btn-primary" {{on "click" this.updateFilters}}>Apply
          Filters</button>
        <button class="btn" {{on "click" @closeModal}}>Cancel</button>
      </:footer>
    </DModal>
  </template>
}
