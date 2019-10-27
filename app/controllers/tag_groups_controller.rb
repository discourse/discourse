# frozen_string_literal: true

class TagGroupsController < ApplicationController
  requires_login
  before_action :ensure_staff

  skip_before_action :check_xhr, only: [:index, :show, :new]
  before_action :fetch_tag_group, only: [:show, :update, :destroy]

  def index
    tag_groups = TagGroup.order('name ASC').includes(:parent_tag).preload(:tags).all
    serializer = ActiveModel::ArraySerializer.new(tag_groups, each_serializer: TagGroupSerializer, root: 'tag_groups')
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
    tag_groups = TagGroup.order('name ASC').includes(:parent_tag).preload(:tags).all
    serializer = ActiveModel::ArraySerializer.new(tag_groups, each_serializer: TagGroupSerializer, root: 'tag_groups')
    store_preloaded "tagGroup", MultiJson.dump(serializer)
    render "default/empty"
  end

  def create
    guardian.ensure_can_admin_tag_groups!
    @tag_group = TagGroup.new(tag_groups_params)
    if @tag_group.save
      render_serialized(@tag_group, TagGroupSerializer)
    else
      render_json_error(@tag_group)
    end
  end

  def update
    guardian.ensure_can_admin_tag_groups!
    json_result(@tag_group, serializer: TagGroupSerializer) do |tag_group|
      @tag_group.update(tag_groups_params)
    end
  end

  def destroy
    guardian.ensure_can_admin_tag_groups!
    @tag_group.destroy
    render json: success_json
  end

  def search
    matches = if params[:q].present?
      TagGroup.where('lower(name) ILIKE ?', "%#{params[:q].strip}%")
    else
      TagGroup.all
    end

    matches = matches.order('name').limit(params[:limit] || 5)

    render json: { results: matches.map { |x| { id: x.name, text: x.name } } }
  end

  private

  def fetch_tag_group
    @tag_group = TagGroup.find(params[:id])
  end

  def tag_groups_params
    tag_group = params.delete(:tag_group)
    params.merge!(tag_group.permit!) if tag_group

    if permissions = params[:permissions]
      permissions.each do |k, v|
        permissions[k] = v.to_i
      end
    end

    result = params.permit(
      :id,
      :name,
      :one_per_topic,
      tag_names: [],
      parent_tag_name: [],
      permissions: permissions&.keys,
    )

    result[:tag_names] ||= []
    result[:parent_tag_name] ||= []
    result[:one_per_topic] = params[:one_per_topic].in?([true, "true"])

    result
  end
end
