# frozen_string_literal: true

class Admin::StaffActionLogsController < Admin::AdminController

  def index
    filters = params.slice(*UserHistory.staff_filters + [:page, :limit])

    page = (params[:page] || 0).to_i
    page_size = (params[:limit] || 200).to_i.clamp(1, 200)

    staff_action_logs = UserHistory.staff_action_records(current_user, filters)
    count = staff_action_logs.count
    staff_action_logs = staff_action_logs.offset(page * page_size).limit(page_size).to_a

    load_more_params = params.permit(UserHistory.staff_filters)
    load_more_params.merge!(page: page + 1, page_size: page_size)

    render_json_dump(
      staff_action_logs: serialize_data(staff_action_logs, UserHistorySerializer),
      total_rows_staff_action_logs: count,
      load_more_staff_action_logs: admin_staff_action_logs_path(load_more_params),
      extras: {
        user_history_actions: staff_available_actions
      }
    )
  end

  def diff
    require_dependency "discourse_diff"

    @history = UserHistory.find(params[:id])
    prev = @history.previous_value
    cur = @history.new_value

    prev = JSON.parse(prev) if prev
    cur = JSON.parse(cur) if cur

    diff_fields = {}

    output = +"<h2>#{CGI.escapeHTML(cur["name"].to_s)}</h2><p></p>"

    diff_fields["name"] = {
      prev: prev["name"].to_s,
      cur: cur["name"].to_s,
    }

    ["default", "user_selectable"].each do |f|
      diff_fields[f] = {
        prev: (!!prev[f]).to_s,
        cur: (!!cur[f]).to_s
      }
    end

    diff_fields["color scheme"] = {
      prev: prev["color_scheme"]&.fetch("name").to_s,
      cur: cur["color_scheme"]&.fetch("name").to_s,
    }

    diff_fields["included themes"] = {
      prev: child_themes(prev),
      cur: child_themes(cur)
    }

    load_diff(diff_fields, :cur, cur)
    load_diff(diff_fields, :prev, prev)

    diff_fields.delete_if { |k, v| v[:cur] == v[:prev] }

    diff_fields.each do |k, v|
      output << "<h3>#{k}</h3><p></p>"
      diff = DiscourseDiff.new(v[:prev] || "", v[:cur] || "")
      output << diff.side_by_side_markdown
    end

    render json: { side_by_side: output }
  end

  protected

  def child_themes(theme)
    return "" unless children = theme["child_themes"]

    children.map { |row| row["name"] }.join(" ").to_s
  end

  def load_diff(hash, key, val)
    if f = val["theme_fields"]
      f.each do |row|
        entry = hash[row["target"] + " " + row["name"]] ||= {}
        entry[key] = row["value"]
      end
    end
  end

  private

  def staff_available_actions
    UserHistory.staff_actions.sort.map do |name|
      {
        id: name,
        action_id: UserHistory.actions[name] || UserHistory.actions[:custom_staff],
      }
    end
  end
end
