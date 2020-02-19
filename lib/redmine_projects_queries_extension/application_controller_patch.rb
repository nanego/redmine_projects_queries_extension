require_dependency 'application_controller'

class ApplicationController

  # Returns the number of objects that should be displayed
  # on the paginated list
  def per_page_option

    if controller_name == 'projects' && action_name == 'index'
      if params[:per_page]
        params[:per_page].to_s.to_i
      else
        1000 # New default limit for projects index page
      end
    else

      ## Beginning of standard method

      per_page = nil
      if params[:per_page] && Setting.per_page_options_array.include?(params[:per_page].to_s.to_i)
        per_page = params[:per_page].to_s.to_i
        session[:per_page] = per_page
      elsif session[:per_page]
        per_page = session[:per_page]
      else
        per_page = Setting.per_page_options_array.first || 25
      end
      per_page

      ## End of standard method

    end
  end

end
