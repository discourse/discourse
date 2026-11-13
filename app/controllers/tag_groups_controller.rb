# frozen_string_literal: true

class TagGroupsController < ApplicationController
  MAX_TAG_GROUPS_SEARCH_RESULTS = 1000 # matches the max limit for max_tag_search_results setting

  requires_login except: [:search]
  before_action :ensure_staff, except: [:search]

  skip_before_action :check_xhr, only: %i[index show new]
  before_action :fetch_tag_group, only: %i[show update destroy]

  def index
    tag_groups = TagGroup.order("name ASC").includes(:parent_tag).preload(:tags).all
    serializer =
      ActiveModel::ArraySerializer.new(
        tag_groups,
        each_serializer: TagGroupSerializer,
        root: "tag_groups",
      )
    respond_to do |format|
      format.html do
        store_preloaded "tagGroups", MultiJson.dump(serializer)
        render "default/empty"
      end
      format.json { render_json_dump(serializer) }
    end
  end

  def show
    serializer = TagGroupSerializer.new(@tag_group)
    respond_to do |format|
      format.html do
        store_preloaded "tagGroup", MultiJson.dump(serializer)
        render "default/empty"
      end
      format.json { render_json_dump(serializer) }
    end
  end

  def new
    tag_groups = TagGroup.order("name ASC").includes(:parent_tag).preload(:tags).all
    serializer =
      ActiveModel::ArraySerializer.new(
        tag_groups,
        each_serializer: TagGroupSerializer,
        root: "tag_groups",
      )
    store_preloaded "tagGroup", MultiJson.dump(serializer)
    render "default/empty"
  end

  def create
    @tag_group = TagGroupCreator.create(guardian, tag_groups_params)
    if @tag_group.persisted?
      render_serialized(@tag_group, TagGroupSerializer)
    else
      render_json_error(@tag_group)
    end
  end

  def update
    json_result(@tag_group, serializer: TagGroupSerializer) do |tag_group|
      TagGroupUpdater.update(guardian, tag_group, tag_groups_params)
    end
  end

  def destroy
    TagGroupDestroyer.destroy(guardian, @tag_group)
    render json: success_json
  end

  def search
    limit =
      fetch_limit_from_params(
        default: SiteSetting.max_tag_search_results,
        max: MAX_TAG_GROUPS_SEARCH_RESULTS,
      )
    results = TagGroupSearch.search(guardian, q: params[:q], names: params[:names], limit:)

    render json: { results: }
  end

  private

  def fetch_tag_group
    @tag_group = TagGroup.find(params[:id])
  end

  def tag_groups_params
    tag_group = params.delete(:tag_group)
    params.merge!(tag_group.permit!) if tag_group

    params.permit(
      :name,
      :one_per_topic,
      tags: %i[id name slug],
      tag_names: [],
      parent_tag: %i[id name slug],
      parent_tag_name: [],
      permissions: {
      },
    )
  end
end
