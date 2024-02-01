require_dependency 'projects_queries_helper'

module RedmineProjectsQueriesExtension
  module QueriesHelperPatch

    def column_content(column, item)
      if item.is_a? Project
        case column.name
        when :issues
          column_content = content_tag(:span, "", class: "open_issues", title: l(:label_open_issues_plural))
          column_content << " / "
          column_content << content_tag(:span, "", class: "closed_issues", title: l(:label_closed_issues_plural))
          column_content.html_safe
        when :role
          if @memberships[item.id].present?
            "<div class='am-i-member member'>#{@memberships[item.id].map(&:name).join("<br>")}</div>".html_safe
          else
            "<div class='am-i-member not-member'>#{l(:label_role_non_member)}</div>".html_safe
          end
        when :activity
          "<span class=barchart></span>".html_safe
        when :users
          "<span></span>".html_safe
        when :members
          members_map[item.id]
        when /role_(\d+)$/
          if organizations_map[item.id] && organizations_map[item.id][$1.to_i]
            organizations_map[item.id][$1.to_i].uniq.join(', ').html_safe
          end
        when /function_(\d+)$/
          if organizations_map[item.id] && organizations_map[item.id][column.name.to_s]
            organizations_map[item.id][column.name.to_s].uniq.join(', ').html_safe
          end
        when /last_issue_date_(\d+)$/
          if trackers_issues_map[item.id] && trackers_issues_map[item.id][column.name.to_s]
            trackers_issues_map[item.id][column.name.to_s].html_safe
          end
        when :organizations
          directions_map[item.id]
        else
          super
        end
      else
        super
      end
    end

    def csv_content(column, project)
      case column.name
      when :issues
        value = ""
      when :organizations
        value = directions_map[project.id]
      when :role
        if @memberships[project.id].present?
          value = @memberships[project.id].map(&:name).join(", ")
        else
          value = l(:label_role_non_member)
        end
      when :members
        value = members_map[project.id]
      when :users
        ""
      when /role_(\d+)$/
        if organizations_map[project.id] && organizations_map[project.id][$1.to_i]
          value = organizations_map[project.id][$1.to_i].join(', ')
        else
          value = ""
        end
      when /function_(\d+)$/
        if organizations_map[project.id] && organizations_map[project.id][column.name.to_s]
          value = organizations_map[project.id][column.name.to_s].uniq.join(', ').html_safe
        end
      when /last_issue_date_(\d+)$/
        if trackers_issues_map[project.id] && trackers_issues_map[project.id][column.name.to_s]
          value = trackers_issues_map[project.id][column.name.to_s].html_safe
        end
      else
        return super
      end
      if value.is_a?(Array)
        value.collect {|v| csv_value(column, project, v)}.uniq.compact.join(', ')
      else
        csv_value(column, project, value)
      end
    end

    def csv_value(column, object, value)
      if value.class.name == 'Organization'
        value.direction_organization.name
      else
        super
      end
    end

    def filters_options_for_select(query)

      s_super = super(query)
      str = s_super
      # get options string
      ungrouped = get_options_by_type(query, :last_issue_date, :label_issue_plural)
      # Regroup options then replace them by its groups
      str = regroup_options_by_type(l(:label_issue_plural), ungrouped, s_super) unless ungrouped.empty?
      str.html_safe
    end

    def get_options_by_type(query, type, label)
      ungrouped = []
      query.available_filters.map do |field, field_options|
        if field_options[:type] == type
          group = label
        end
        if group
          ungrouped << [field_options[:name], field]
        end
      end

      return ungrouped
    end

    def regroup_options_by_type(label, options, s_super)
      str_options = options_for_select_without_non_empty_blank_option(options, nil)
      str = []
      str = [label, options]

      str_group = grouped_options_for_select([str])
      result = s_super.sub(str_options, str_group)
      result
    end
  end
end

QueriesHelper.prepend RedmineProjectsQueriesExtension::QueriesHelperPatch
ActionView::Base.prepend QueriesHelper
IssuesController.prepend QueriesHelper
ProjectsController.prepend QueriesHelper
