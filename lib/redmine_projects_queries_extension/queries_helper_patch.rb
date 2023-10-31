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

  end
end

QueriesHelper.prepend RedmineProjectsQueriesExtension::QueriesHelperPatch
ActionView::Base.prepend QueriesHelper
IssuesController.prepend QueriesHelper
ProjectsController.prepend QueriesHelper
