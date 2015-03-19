class DirectoryItemsController < ApplicationController
  PAGE_SIZE = 50

  def index
    period = params.require(:period)
    period_type = DirectoryItem.period_types[period.to_sym]
    raise Discourse::InvalidAccess.new(:period_type) unless period_type

    result = DirectoryItem.where(period_type: period_type).includes(:user)

    order = params[:order] || DirectoryItem.headings.first
    if DirectoryItem.headings.include?(order.to_sym)
      dir = params[:asc] ? 'ASC' : 'DESC'
      result = result.order("directory_items.#{order} #{dir}")
    end

    if period_type == DirectoryItem.period_types[:all]
      result = result.includes(:user_stat)
    end
    page = params[:page].to_i
    result = result.order('users.username')
    result_count = result.dup.count
    result = result.limit(PAGE_SIZE).offset(PAGE_SIZE * page)

    more_params = params.slice(:period, :order, :asc)
    more_params[:page] = page + 1

    render_json_dump directory_items: serialize_data(result, DirectoryItemSerializer),
                     total_rows_directory_items: result_count,
                     load_more_directory_items: directory_items_path(more_params)

  end
end
