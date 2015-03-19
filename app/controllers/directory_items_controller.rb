class DirectoryItemsController < ApplicationController
  PAGE_SIZE = 50

  def index
    period = params.require(:period)
    period_type = DirectoryItem.period_types[period.to_sym]
    raise Discourse::InvalidAccess.new(:period_type) unless period_type

    result = DirectoryItem.where(period_type: period_type).includes(:user)

    if current_user.present?
      result = result.order("CASE WHEN users.id = #{current_user.id.to_i} THEN 0 ELSE 1 END")
    end

    order = params[:order] || DirectoryItem.headings.first
    if DirectoryItem.headings.include?(order.to_sym)
      dir = params[:asc] ? 'ASC' : 'DESC'
      result = result.order("directory_items.#{order} #{dir}")
    end

    if period_type == DirectoryItem.period_types[:all]
      result = result.includes(:user_stat)
    end
    page = params[:page].to_i

    user_ids = nil
    if params[:name].present?
      user_ids = UserSearch.new(params[:name]).search.pluck(:id)
      if user_ids.present?
        # Add the current user if we have at least one other match
        if current_user && result.dup.where(user_id: user_ids).count > 0
          user_ids << current_user.id
        end
        result = result.where(user_id: user_ids)
      else
        result = result.where('false')
      end
    end

    result = result.order('users.username')
    result_count = result.dup.count
    result = result.limit(PAGE_SIZE).offset(PAGE_SIZE * page).to_a

    more_params = params.slice(:period, :order, :asc)
    more_params[:page] = page + 1

    render_json_dump directory_items: serialize_data(result, DirectoryItemSerializer),
                     total_rows_directory_items: result_count,
                     load_more_directory_items: directory_items_path(more_params)

  end
end
