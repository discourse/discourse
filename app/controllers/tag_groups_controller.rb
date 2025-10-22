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
    guardian.ensure_can_admin_tag_groups!
    @tag_group = TagGroup.new(tag_groups_params)
    if @tag_group.save
      StaffActionLogger.new(current_user).log_tag_group_create(
        @tag_group.name,
        TagGroupSerializer.new(@tag_group).to_json(root: false),
      )
      render_serialized(@tag_group, TagGroupSerializer)
    else
      render_json_error(@tag_group)
    end
  end

  def update
    guardian.ensure_can_admin_tag_groups!
    old_data = TagGroupSerializer.new(@tag_group).to_json(root: false)
    json_result(@tag_group, serializer: TagGroupSerializer) do |tag_group|
      @tag_group.update(tag_groups_params)
      new_data = TagGroupSerializer.new(@tag_group).to_json(root: false)
      StaffActionLogger.new(current_user).log_tag_group_change(@tag_group.name, old_data, new_data)
    end
  end

  def destroy
    guardian.ensure_can_admin_tag_groups!
    StaffActionLogger.new(current_user).log_tag_group_destroy(
      @tag_group.name,
      TagGroupSerializer.new(@tag_group).to_json(root: false),
    )
    @tag_group.destroy
    render json: success_json
  end

  def search
    matches = TagGroup.includes(:tags).visible(guardian).all

    matches = matches.where("lower(name) ILIKE ?", "%#{params[:q].strip}%") if params[:q].present?

    if params[:names].present?
      matches = matches.where("lower(NAME) in (?)", params[:names].map(&:downcase))
    end

    matches =
      matches.order("name").limit(
        fetch_limit_from_params(
          default: SiteSetting.max_tag_search_results,
          max: MAX_TAG_GROUPS_SEARCH_RESULTS,
        ),
      )

    render json: {
             results:
               matches.map { |x| { name: x.name, tag_names: x.tags.base_tags.pluck(:name).sort } },
           }
  end

  private

  def fetch_tag_group
    @tag_group = TagGroup.find(params[:id])
  end

  def tag_groups_params
    tag_group = params.delete(:tag_group)
    params.merge!(tag_group.permit!) if tag_group

    result =
      params.permit(:id, :name, :one_per_topic, tag_names: [], parent_tag_name: [], permissions: {})

    result[:tag_names] ||= []
    result[:parent_tag_name] ||= []
    result[:one_per_topic] = params[:one_per_topic].in?([true, "true"])

    result
  end
end
